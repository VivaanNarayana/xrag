#!/usr/bin/env python3
"""
XRAG - Cross-Session Vector Context Memory - Core Vector Store
Handles embedding, retrieval, and storage of AI responses using semantic search.
"""

import os
import sys
import json
import argparse
import numpy as np
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Optional, Tuple
import math

# Lazy imports for model loading
_model = None
_index = None


class VectorStore:
    def __init__(self, config_path: Optional[str] = None):
        """Initialize vector store with configuration."""
        self.script_dir = Path(__file__).parent
        self.config_path = config_path or self.script_dir / "config.json"
        self.config = self._load_config()
        self.storage_path = Path(self.config["storage_path"])
        self.storage_path.parent.mkdir(parents=True, exist_ok=True)
        
    def _load_config(self) -> Dict:
        """Load configuration from config.json."""
        try:
            with open(self.config_path, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            return self._default_config()
    
    def _default_config(self) -> Dict:
        """Return default configuration."""
        return {
            "max_entries": 100,
            "embedding_model": "all-MiniLM-L6-v2",
            "similarity_weight": 0.7,
            "recency_weight": 0.3,
            "retrieve_top_k": 3,
            "storage_path": str(self.script_dir / ".vectorstore"),
            "prune_percentage": 0.2,
            "auto_cleanup_on_exit": True,
            "min_similarity_threshold": 0.5,
            "max_text_length": 10000
        }
    
    def _load_model(self):
        """Lazy load the sentence transformer model."""
        global _model
        if _model is None:
            try:
                from sentence_transformers import SentenceTransformer
                print(f"Loading embedding model: {self.config['embedding_model']}...", file=sys.stderr)
                _model = SentenceTransformer(self.config['embedding_model'])
                print("Model loaded successfully.", file=sys.stderr)
            except ImportError:
                print("ERROR: sentence-transformers not installed.", file=sys.stderr)
                print("Run: pip install sentence-transformers", file=sys.stderr)
                sys.exit(1)
            except Exception as e:
                print(f"ERROR: Failed to load model: {e}", file=sys.stderr)
                sys.exit(1)
        return _model
    
    def _load_faiss(self):
        """Lazy load FAISS library."""
        try:
            import faiss
            return faiss
        except ImportError:
            print("ERROR: faiss-cpu not installed.", file=sys.stderr)
            print("Run: pip install faiss-cpu", file=sys.stderr)
            sys.exit(1)
    
    def _load_storage(self) -> Dict:
        """Load existing storage data."""
        if not self.storage_path.exists():
            return {
                "embeddings": [],
                "responses": [],
                "metadata": []
            }
        
        try:
            with open(self.storage_path, 'r', encoding='utf-8') as f:
                return json.load(f)
        except (json.JSONDecodeError, FileNotFoundError):
            print("WARNING: Corrupted storage, rebuilding from scratch.", file=sys.stderr)
            return {
                "embeddings": [],
                "responses": [],
                "metadata": []
            }
    
    def _save_storage(self, data: Dict):
        """Save storage data to disk."""
        with open(self.storage_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)
    
    def _build_index(self, embeddings: List[List[float]]):
        """Build FAISS index from embeddings."""
        global _index
        faiss = self._load_faiss()
        
        if not embeddings:
            dimension = 384
            _index = faiss.IndexFlatIP(dimension)
            return _index
        
        embeddings_array = np.array(embeddings, dtype=np.float32)
        dimension = embeddings_array.shape[1]
        
        _index = faiss.IndexFlatIP(dimension)
        _index.add(embeddings_array)
        
        return _index
    
    def embed(self, text: str) -> np.ndarray:
        """Generate embedding for text."""
        model = self._load_model()
        
        if len(text) > self.config["max_text_length"]:
            text = text[:self.config["max_text_length"]]
        
        embedding = model.encode(text, convert_to_numpy=True, normalize_embeddings=True)
        return embedding
    
    def _calculate_recency_score(self, position: int, total: int) -> float:
        """Calculate recency score based on position from end."""
        if total <= 1:
            return 1.0
        
        position_from_end = total - position
        return 1.0 / (1.0 + math.log(position_from_end + 1))
    
    def retrieve(self, query: str, top_k: Optional[int] = None) -> List[Dict]:
        """Retrieve most relevant responses for query."""
        if top_k is None:
            top_k = self.config["retrieve_top_k"]
        
        storage = self._load_storage()
        
        if not storage["embeddings"]:
            return []
        
        query_embedding = self.embed(query)
        query_embedding = query_embedding.reshape(1, -1).astype(np.float32)
        
        index = self._build_index(storage["embeddings"])
        
        k = min(top_k * 2, len(storage["embeddings"]))
        distances, indices = index.search(query_embedding, k)
        
        results = []
        total_entries = len(storage["responses"])
        
        for idx, (distance, position) in enumerate(zip(distances[0], indices[0])):
            if position >= len(storage["responses"]):
                continue
            
            semantic_score = float(distance)
            recency_score = self._calculate_recency_score(int(position), total_entries)
            
            hybrid_score = (
                semantic_score * self.config["similarity_weight"] +
                recency_score * self.config["recency_weight"]
            )
            
            if semantic_score < self.config["min_similarity_threshold"]:
                continue
            
            metadata = storage["metadata"][position]
            metadata["last_accessed"] = datetime.now().isoformat()
            metadata["access_count"] = metadata.get("access_count", 0) + 1
            
            results.append({
                "text": storage["responses"][position],
                "score": round(hybrid_score, 4),
                "semantic_score": round(semantic_score, 4),
                "recency_score": round(recency_score, 4),
                "timestamp": metadata.get("timestamp", "unknown"),
                "length": metadata.get("length", 0),
                "position": int(position)
            })
        
        results.sort(key=lambda x: x["score"], reverse=True)
        results = results[:top_k]
        
        self._save_storage(storage)
        
        return results
    
    def store(self, response: str, timestamp: Optional[str] = None, metadata: Optional[Dict] = None):
        """Store AI response with embedding."""
        if not response or len(response.strip()) < 10:
            print("WARNING: Response too short to store.", file=sys.stderr)
            return
        
        storage = self._load_storage()
        
        embedding = self.embed(response)
        
        if timestamp is None:
            timestamp = datetime.now().isoformat()
        
        entry_metadata = {
            "timestamp": timestamp,
            "last_accessed": timestamp,
            "access_count": 0,
            "length": len(response)
        }
        
        if metadata:
            entry_metadata.update(metadata)
        
        storage["embeddings"].append(embedding.tolist())
        storage["responses"].append(response)
        storage["metadata"].append(entry_metadata)
        
        if len(storage["responses"]) > self.config["max_entries"]:
            storage = self._prune_lru(storage)
        
        self._save_storage(storage)
        
        print(f"Stored response ({len(response)} chars). Total entries: {len(storage['responses'])}", file=sys.stderr)
    
    def _prune_lru(self, storage: Dict) -> Dict:
        """Prune storage using LRU strategy."""
        target_count = int(self.config["max_entries"] * (1 - self.config["prune_percentage"]))
        
        print(f"Pruning from {len(storage['responses'])} to {target_count} entries...", file=sys.stderr)
        
        scored_entries = []
        for i, meta in enumerate(storage["metadata"]):
            last_accessed = datetime.fromisoformat(meta.get("last_accessed", meta.get("timestamp", "2000-01-01T00:00:00")))
            age_seconds = (datetime.now() - last_accessed).total_seconds()
            
            access_count = meta.get("access_count", 0)
            
            lru_score = age_seconds / (1 + access_count)
            
            scored_entries.append((i, lru_score))
        
        scored_entries.sort(key=lambda x: x[1])
        
        keep_indices = sorted([idx for idx, _ in scored_entries[:target_count]])
        
        storage["embeddings"] = [storage["embeddings"][i] for i in keep_indices]
        storage["responses"] = [storage["responses"][i] for i in keep_indices]
        storage["metadata"] = [storage["metadata"][i] for i in keep_indices]
        
        print(f"Pruned to {len(storage['responses'])} entries.", file=sys.stderr)
        
        return storage
    
    def prune(self, target_count: int):
        """Manually prune to target count."""
        storage = self._load_storage()
        
        if len(storage["responses"]) <= target_count:
            print(f"Storage has {len(storage['responses'])} entries, no pruning needed.", file=sys.stderr)
            return
        
        self.config["max_entries"] = target_count
        self.config["prune_percentage"] = 0
        
        storage = self._prune_lru(storage)
        self._save_storage(storage)
    
    def stats(self) -> Dict:
        """Get storage statistics."""
        storage = self._load_storage()
        
        if not storage["responses"]:
            return {
                "total_entries": 0,
                "storage_size_kb": 0,
                "oldest_entry": None,
                "newest_entry": None
            }
        
        timestamps = [m.get("timestamp", "2000-01-01T00:00:00") for m in storage["metadata"]]
        
        storage_size = 0
        if self.storage_path.exists():
            storage_size = self.storage_path.stat().st_size / 1024
        
        return {
            "total_entries": len(storage["responses"]),
            "storage_size_kb": round(storage_size, 2),
            "oldest_entry": min(timestamps),
            "newest_entry": max(timestamps),
            "avg_response_length": round(sum(len(r) for r in storage["responses"]) / len(storage["responses"]), 2),
            "max_entries": self.config["max_entries"]
        }
    
    def list_recent(self, count: int = 10) -> List[Dict]:
        """List most recent entries."""
        storage = self._load_storage()
        
        if not storage["responses"]:
            return []
        
        recent_entries = []
        for i in range(max(0, len(storage["responses"]) - count), len(storage["responses"])):
            recent_entries.append({
                "position": i,
                "timestamp": storage["metadata"][i].get("timestamp", "unknown"),
                "length": storage["metadata"][i].get("length", 0),
                "preview": storage["responses"][i][:100] + "..." if len(storage["responses"][i]) > 100 else storage["responses"][i]
            })
        
        return list(reversed(recent_entries))
    
    def init(self, clean: bool = False):
        """Initialize vector store."""
        if clean and self.storage_path.exists():
            self.storage_path.unlink()
            print("Cleaned existing storage.", file=sys.stderr)
        
        self._load_model()
        
        storage = self._load_storage()
        self._save_storage(storage)
        
        print(f"Vector store initialized at: {self.storage_path}", file=sys.stderr)
        print(f"Max entries: {self.config['max_entries']}", file=sys.stderr)


def main():
    """CLI interface for vector store operations."""
    parser = argparse.ArgumentParser(description="Ephemeral Vector Context Memory")
    subparsers = parser.add_subparsers(dest="command", help="Command to execute")
    
    init_parser = subparsers.add_parser("init", help="Initialize vector store")
    init_parser.add_argument("--clean", action="store_true", help="Clean existing storage")
    
    retrieve_parser = subparsers.add_parser("retrieve", help="Retrieve relevant context")
    retrieve_parser.add_argument("query", type=str, help="Query text")
    retrieve_parser.add_argument("--top-k", type=int, help="Number of results")
    
    store_parser = subparsers.add_parser("store", help="Store AI response")
    store_parser.add_argument("response", type=str, help="Response text")
    store_parser.add_argument("--timestamp", type=str, help="Timestamp (ISO format)")
    store_parser.add_argument("--metadata", type=str, help="Additional metadata (JSON)")
    
    prune_parser = subparsers.add_parser("prune", help="Manually prune storage")
    prune_parser.add_argument("--target", type=int, required=True, help="Target entry count")
    
    subparsers.add_parser("stats", help="Show storage statistics")
    
    list_parser = subparsers.add_parser("list", help="List recent entries")
    list_parser.add_argument("--recent", type=int, default=10, help="Number of recent entries")
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    store = VectorStore()
    
    try:
        if args.command == "init":
            store.init(clean=args.clean)
        
        elif args.command == "retrieve":
            results = store.retrieve(args.query, top_k=args.top_k)
            output = {
                "results": results,
                "count": len(results)
            }
            print(json.dumps(output, indent=2))
        
        elif args.command == "store":
            metadata = None
            if args.metadata:
                metadata = json.loads(args.metadata)
            store.store(args.response, timestamp=args.timestamp, metadata=metadata)
        
        elif args.command == "prune":
            store.prune(args.target)
        
        elif args.command == "stats":
            stats = store.stats()
            print(json.dumps(stats, indent=2))
        
        elif args.command == "list":
            entries = store.list_recent(args.recent)
            print(json.dumps(entries, indent=2))
    
    except KeyboardInterrupt:
        print("\nOperation cancelled.", file=sys.stderr)
        sys.exit(130)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
