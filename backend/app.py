from fastapi import FastAPI, Request, UploadFile, HTTPException, File, status
from fastapi.middleware.cors import CORSMiddleware
from tempfile import NamedTemporaryFile
from pydantic import BaseModel
from dotenv import load_dotenv
from enum import Enum
from utils import CompletionAI
from pydub import AudioSegment
from prompts import *
import uvicorn
import openai
import os, io
import concurrent.futures
import time
import logging

logging.basicConfig(level=logging.INFO)
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
    professional = 'professional'

class Format(str, Enum):
    bullet = 'bullet'
    paragraph = 'paragraph'

class OutputType(str, Enum):
    Summary = 'Summary'
    Title = 'Title'

class TransformType(str, Enum):
    actions = 'actions'
    ideas = 'ideas'
    journal = 'journal'

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

class TransformLoad(BaseModel):
    type: TransformType
    transcript: str
    settings: Settings

@app.get('/')
def get():
    return {"res": "success"}

@app.post('/api/v1/transcribe')
async def transcribe(file: UploadFile = File(...)):
    contents = await file.read()
    chunk_size = 10000000  
    audio = AudioSegment.from_file(io.BytesIO(contents), format="m4a")

    # calculate chunk_size in ms equivalent (approximated)
    bytes_per_ms = len(contents) / len(audio)
    chunk_length_ms = int(chunk_size / bytes_per_ms)

    chunks = [audio[i:i + chunk_length_ms] for i in range(0, len(audio), chunk_length_ms)]
    logging.debug(f'number of chunks: {len(chunks)}')
    logging.debug(f'chunk len: {[len(chunk) for chunk in chunks]}')

    transcripts = []
    with concurrent.futures.ThreadPoolExecutor() as executor:
        future_to_transcript = {executor.submit(transcribe_chunk, chunk, i): chunk for i, chunk in enumerate(chunks)}
        for future in concurrent.futures.as_completed(future_to_transcript):
            future_to_transcript[future]
            try:
                transcripts.append(future.result())
            except Exception as exc:
                logging.debug(f'generated an exception: {exc}')

    transcripts.sort(key=lambda x: x[1])
    transcript = ' '.join([transcript[0] for transcript in transcripts])

    logging.debug(f'transcripts: {transcripts}')
    logging.debug(f'transcript: {transcript}')

    return {'transcript': transcript}

def transcribe_chunk(chunk: AudioSegment, index: int):
    s = time.time()
    with NamedTemporaryFile(suffix=".mp3", delete=True) as tmp:
        chunk.export(tmp, format='mp3')
        tmp.flush()

        # Check if the file format is .m4a before sending request
        with open(tmp.name, 'rb') as audio_file:
            transcript = openai.Audio.transcribe(
                'whisper-1',
                file=audio_file, 
                options={
                    'language': 'en', 
                    'prompt': 'talking about some things I have done today'
                }
            )['text']
    e = time.time()
    logging.debug(f'chunk {index} time: {e-s}')
    return transcript, index

@app.post('/api/v1/generate_output')
async def generate_output(load: OutputLoad):
    if load.type == 'Summary':
        #raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,detail="Missing Authorization header")
        #print(load.type)
        gpt = CompletionAI(
            get_summary_out,
            load.transcript, 
            length=load.settings.length, 
            tone=load.settings.tone, 
            format=load.settings.format
            ) 
        out: str = await gpt() 
        out = out.replace('*', '-') 
    elif load.type == 'Title':
        #print(load.type)
        gpt = CompletionAI(
            get_title,
            load.transcript 
            )
        out: str = await gpt()
        out = out.replace('"', '') 
        out = out.replace("'", '') 
    return {'out': out}

@app.post('/api/v1/generate_transform')
async def generate_transform(load: TransformLoad):
    if load.type == 'actions':
        gpt = CompletionAI(
            get_actions_out,
            load.transcript, 
            length=load.settings.length, 
            tone=load.settings.tone, 
            format=load.settings.format
            ) 
        out: str = await gpt() 
        out = out.replace('*', '-') 
    elif load.type == 'ideas':
        gpt = CompletionAI(
            get_ideas_out,
            load.transcript, 
            length=load.settings.length, 
            tone=load.settings.tone, 
            format=load.settings.format
            ) 
        out: str = await gpt() 
        out = out.replace('*', '-') 
    elif load.type == 'journal':
        gpt = CompletionAI(
            get_journal_out,
            load.transcript, 
            length=load.settings.length, 
            tone=load.settings.tone, 
            format=load.settings.format
            ) 
        out: str = await gpt() 
        out = out.replace('*', '-') 
    return {'out': out}

if __name__ == "__main__":
    uvicorn.run(app,host='0.0.0.0', port=3000)