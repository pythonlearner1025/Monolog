import openai
import tiktoken
import os
from dotenv import load_dotenv
from tenacity import (
    retry,
    stop_after_attempt,
    wait_random_exponential,
)  # for
from langchain.text_splitter import NLTKTextSplitter
from prompts import get_summary_system
import asyncio
import nltk

nltk.download('punkt')
load_dotenv()

@retry(wait=wait_random_exponential(min=1, max=60), stop=stop_after_attempt(6))
def completion_with_backoff(**kwargs):
    openai.api_key = os.getenv('OPENAI_API_KEY') 
    return openai.ChatCompletion.create(**kwargs)

# TODO: what if the transcript is too long? 
class CompletionAI:
    def __init__(self, system_fn, user_msg, **kwargs):
        self.user_msg = user_msg
        self.messages = []
        self.messages.append({"role": "system", "content": system_fn(user_msg, **kwargs)})
        self.encoding = tiktoken.encoding_for_model("gpt-3.5-turbo")
        self.system_fn = system_fn
    
    async def __call__(self): return  await self.run()

    def raw_run(self):
        #self.messages.append({"role": "user", "content": message}) 
        completion = completion_with_backoff(model="gpt-3.5-turbo", messages=self.messages)
        ret = completion.choices[0].message.content 
        print("-- raw run completion --")
        print(ret)
        return ret
    
    async def run(self):
        await self.summarize(self.count(), i=0)
        completion = completion_with_backoff(model="gpt-3.5-turbo", messages=self.messages)
        ret = completion.choices[0].message.content
        print('-- FINAL RET --')
        print(ret)
        return ret
        
    def count(self):
        print("*"*20, 'count', '*'*20)
        sys = len(self.encoding.encode(self.messages[0]['content']))
        print(f'length: {sys}')
        return sys
    
    async def run_summary(self, f, *args):
        return await asyncio.get_running_loop().run_in_executor(None, lambda: f(*args))
    
    async def summarize(self, count, i=0):
        if count < 4096: 
            print("-- NO NEED OF SUMMARY --")
            return
        print(f'-- SUMMARY TRY {i} --')
        print(f'current length: ', count)
        splitter = NLTKTextSplitter.from_tiktoken_encoder(
            chunk_size=4000, 
            chunk_overlap=500, 
            encoding_name='gpt-3.5-turbo', 
            model_name='gpt-3.5-turbo'
            )
        split = splitter.split_text(self.user_msg)
        print(f'number of splits: {len(split)}')

        tasks = []
        for seg in split:
            summary_bot = CompletionAI(get_summary_system,seg)
            tasks.append(asyncio.create_task(self.run_summary(summary_bot.raw_run)))
            print('-'*50)
            print(len(self.encoding.encode(seg)))

        results = await asyncio.gather(*tasks)
        summary = ''.join(results)
        summary_len, sys_len = len(self.encoding.encode(summary)),len(self.encoding.encode(self.system_fn('')))
        self.user_msg = summary
        self.messages[0]['content'] = self.system_fn(self.user_msg)

        print('-- SUMMARY RESULT --')
        print(f'num results: {len(results)}')
        print(f'summary tokens: {summary_len}')

        await self.summarize(sys_len+summary_len, i=i+1)


if __name__ == '__main__':
    from prompts import *
    from itertools import islice
    testfile = '/Users/minjunes/Downloads/t8.shakespeare.txt'
    with open(testfile, 'r') as f:
        lines = list(islice(f, 5000))  # read first X lines
        text = ''.join(lines)  # join them into a single string
        #print(f'text length: {len(text)}')
    testbot = CompletionAI(get_summary_out, text)
    res = asyncio.run(testbot())

