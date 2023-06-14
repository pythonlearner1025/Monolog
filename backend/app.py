from fastapi import FastAPI, Request, UploadFile, HTTPException, File, status
from fastapi.middleware.cors import CORSMiddleware
from tempfile import NamedTemporaryFile
from pydantic import BaseModel
from dotenv import load_dotenv
from enum import Enum
from utils import CompletionAI
from prompts import *
import uvicorn
import openai
import requests
import base64
import os


load_dotenv()

openai.api_key = os.getenv('OPENAI_API_KEY')

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

ALLOWED_API_KEYS=[
    '046cc07d8daab73e53e9089dda05acf4750e1a3cd23c87bff0cbafd0975a949b'
]

def verify_api_key(req: Request):
    if 'Authorization' not in req.headers:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header"
        )
    tok = str(req.headers['Authorization']).replace('Bearer ', '')
    if tok not in ALLOWED_API_KEYS:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Forbidden"
        )

class Length(str, Enum):
    short = 'short'
    medium = 'medium'
    long = 'long'

class Tone(str, Enum):
    casual = 'casual' 
    formal = 'formal'

class Format(str, Enum):
    bullet = 'bullet'
    paragraph = 'paragraph'

class OutputType(str, Enum):
    Summary = 'Summary'
    Action = 'Action'
    Custom = 'Custom'
    Title = 'Title'

class Settings(BaseModel):
    length: Length
    format: Format
    tone: Tone
    name: str
    prompt: str

class OutputLoad(BaseModel):
    type: OutputType
    transcript: str
    settings: Settings

@app.get('/')
def get():
    return {"res": "success"}

@app.post('/api/v1/transcribe')
async def transcribe(file: UploadFile = File(...)):
    if file.size >= 25000000:
        return {'transcript': None}
    contents = await file.read()
    # Create a temporary file using NamedTemporaryFile
    with NamedTemporaryFile(suffix=".m4a", delete=True) as tmp:
        tmp.write(contents)
        tmp.flush()

        # Re-open the temp file in read mode and send to openai
        with open(tmp.name, 'rb') as audio_file:
            transcript = openai.Audio.transcribe(
                'whisper-1',
                file=audio_file, 
                options={
                    'language': 'en', 
                    'prompt': 'talking about some things I have done today'
                }
            )['text']
    print('*'*10, 'transcript', '*'*10)
    print(transcript)
    return {'transcript': transcript}

@app.post('/api/v1/generate_output')
async def generate_output(load: OutputLoad):
    if load.type == 'Summary':
        #raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,detail="Missing Authorization header")
        print(load.type)
        gpt = CompletionAI(
            get_summary_out,
            load.transcript, 
            length=load.settings.length, 
            tone=load.settings.tone, 
            format=load.settings.format
            ) 
        out: str = await gpt() 
        out = out.replace('*', '-') 
    elif load.type == 'Action':
        print(load.type)
        gpt = CompletionAI(
            get_action_out,
            load.transcript, 
            length=load.settings.length, 
            tone=load.settings.tone, 
            format=load.settings.format
            )
        out: str = await gpt()
        out = out.replace('*', '-') 
    elif load.type == 'Title':
        print(load.type)
        gpt = CompletionAI(
            get_title,
            load.transcript 
            )
        out: str = await gpt()
        out = out.replace('"', '') 
        out = out.replace("'", '') 
    else:
        print(load.type)
        gpt = CompletionAI(
            get_custom_out, 
            load.transcript, 
            prompt=load.settings.prompt, 
            length=load.settings.length, 
            tone=load.settings.tone, 
            format=load.settings.format
            )
        out: str = await gpt()
    return {'out': out}

if __name__ == "__main__":
    uvicorn.run(app,host='0.0.0.0', port=3000)