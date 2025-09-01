from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Dict, Optional
from datetime import datetime
import os

app = FastAPI(
    title="AI Receptionist API",
    description="Open-source multi-tenant AI receptionist platform",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Simple in-memory storage for now
businesses_db = []
calls_db = []

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "services": {
            "api": True,
            "database": True  # Will implement database connection later
        },
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/businesses")
async def get_businesses():
    """Get all businesses"""
    return businesses_db

@app.post("/businesses")
async def create_business(business_data: dict):
    """Create a new business"""
    business = {
        "id": len(businesses_db) + 1,
        "name": business_data.get("name"),
        "phone": business_data.get("phone_number", ""),
        "industry": business_data.get("industry", ""),
        "welcome_message": business_data.get("welcome_message", ""),
        "status": "active",
        "created_at": datetime.utcnow().isoformat()
    }
    businesses_db.append(business)
    return business

@app.put("/businesses/{business_id}")
async def update_business(business_id: int, business_data: dict):
    """Update a business"""
    for i, business in enumerate(businesses_db):
        if business["id"] == business_id:
            businesses_db[i].update({
                "name": business_data.get("name", business["name"]),
                "phone": business_data.get("phone_number", business["phone"]),
                "industry": business_data.get("industry", business["industry"]),
                "welcome_message": business_data.get("welcome_message", business.get("welcome_message", "")),
            })
            return businesses_db[i]
    raise HTTPException(status_code=404, detail="Business not found")

@app.delete("/businesses/{business_id}")
async def delete_business(business_id: int):
    """Delete a business"""
    for i, business in enumerate(businesses_db):
        if business["id"] == business_id:
            deleted_business = businesses_db.pop(i)
            return {"message": "Business deleted successfully", "business": deleted_business}
    raise HTTPException(status_code=404, detail="Business not found")

@app.get("/businesses/{business_id}/calls")
async def get_business_calls(business_id: int, limit: int = 100):
    """Get calls for a specific business"""
    business_calls = [call for call in calls_db if call.get("business_id") == business_id]
    return business_calls[:limit]

@app.post("/call/start")
async def start_call(call_data: dict):
    """Handle incoming call initiation"""
    call = {
        "id": len(calls_db) + 1,
        "caller_id": call_data.get("caller_id"),
        "business_id": call_data.get("business_id"),
        "start_time": datetime.utcnow().isoformat(),
        "status": "active"
    }
    calls_db.append(call)
    return {"message": "Call started", "call_id": call["id"]}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
