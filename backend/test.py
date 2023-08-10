import openai
import os
from dotenv import load_dotenv

if __name__ == "__main__":
    load_dotenv()
    openai.api_key = os.getenv('OPENAI_API_KEY')
    import time
    #f = '/Users/minjunes/Downloads/idea generation w speech.m4a'
    f = '/Users/minjunes/Downloads/Counting with Numbers..m4a'
    s = time.time()
    with open(f, 'rb') as audio_file:
        transcript = openai.Audio.transcribe(
            'whisper-1',
            file=audio_file, 
            response_format="verbose_json",
            options={
                'language': 'en', 
                'prompt': 'talking about some things I have done today'
            }
        )
    e = time.time()
    print(transcript)
    print(e-s)

