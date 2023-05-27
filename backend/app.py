from fastapi import FastAPI, Request, UploadFile, HTTPException, File, status
from fastapi.middleware.cors import CORSMiddleware
from tempfile import NamedTemporaryFile
from pydantic import BaseModel
from dotenv import load_dotenv
from enum import Enum
from utils import ChatBot
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

class Style(str, Enum):
    casual = 'casual' 
    formal = 'formal'

class Format(str, Enum):
    bullet = 'bullet'
    paragraph = 'paragraph'

class OutputType(str, Enum):
    Summary = 'Summary'
    Action = 'Action'

class Settings(BaseModel):
    length: Length
    style: Style
    format: Format

class TitleLoad(BaseModel):
    transcript: str

class OutputLoad(BaseModel):
    type: OutputType
    #settings: Settings
    transcript: str

@app.post('/api/v1/transcribe')
async def transcribe(file: UploadFile = File(...)):
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


@app.post('/api/v1/generate_title')
def generate_title(load: TitleLoad):
    gpt = ChatBot(system=TITLE_SYSTEM)
    title = gpt(load.transcript)
    return {'title': title}

@app.post('/api/v1/generate_output')
def generate_output(load: OutputLoad):
    if load.type == 'Summary':
        gpt = ChatBot(system=SUMMARY_SYSTEM) 
        out = gpt(load.transcript) 
    elif load.type == 'Action':
        gpt = ChatBot(system=ACTION_SYSTEM)
        out = gpt(load.transcript)
    return {'out': out}

if __name__ == "__main__":
    uvicorn.run(app,host='0.0.0.0', port=3000)