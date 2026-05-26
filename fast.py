from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import ollama
from datetime import datetime
import uvicorn

app = FastAPI()

# Enable CORS for iOS app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ChatRequest(BaseModel):
    user_input: str
    conversation_id: str
    user_id: str

class ChatResponse(BaseModel):
    response: str
    conversation_id: str
    timestamp: str

MODEL_NAME = "phi3:mini"

SYSTEM_PROMPT = """
You are BMCC Advisor, an academic advisor for Borough of Manhattan Community College (CUNY).

IMPORTANT RULES:
1. Always reference actual BMCC courses with their codes (e.g., CSC 111, MAT 301)
2. Verify prerequisites before recommending any course
3. Consider the student's schedule type when planning credit load
4. Calculate remaining semesters based on graduation year
5. Be helpful, accurate, and honest. If unsure, say "I recommend speaking with your academic advisor"
6. Never invent courses or requirements not in the BMCC catalog
7. Format responses clearly with bullet points when listing multiple items

Respond naturally as a helpful academic advisor.
"""

@app.post("/chat")
async def chat(request: ChatRequest):
    try:
        print(f"\n📱 User: {request.user_id}")
        print(f"💬 Message: {request.user_input[:100]}...")
        
        full_prompt = f"{SYSTEM_PROMPT}\n\n{request.user_input}"
        
        response = ollama.chat(
            model=MODEL_NAME,
            messages=[{"role": "user", "content": full_prompt}],
            options={
                "temperature": 0.7,
                "num_predict": 1024,
            }
        )
        
        reply = response['message']['content']
        print(f"✅ Response sent: {reply[:100]}...")
        
        return ChatResponse(
            response=reply,
            conversation_id=request.conversation_id,
            timestamp=datetime.now().isoformat()
        )
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health():
    return {"status": "ok", "model": MODEL_NAME}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
