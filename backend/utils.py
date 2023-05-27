import openai
import tiktoken
import os
from dotenv import load_dotenv

load_dotenv()

# TODO: what if the transcript is too long? 
class ChatBot:
    def __init__(self, system=""):
        self.openai = openai
        self.openai.api_key = os.getenv('OPENAI_API_KEY') 
        self.system = system
        self.messages = []
        if self.system:
            self.messages.append({"role": "system", "content": system})
        self.encoding = tiktoken.encoding_for_model("gpt-3.5-turbo")
    
    def __call__(self, message):
        self.messages.append({"role": "user", "content": message})
        if self.count() >= 4096: self.cut()            
        result = self.execute()
        self.messages.append({"role": "assistant", "content": result})
        return result
        
    def count(self):
        print("*"*20, 'count', '*'*20)
        total = ''
        for msg in self.messages:
            total += msg['content']
        encoding = tiktoken.encoding_for_model("gpt-3.5-turbo")
        length = len(encoding.encode(total))
        print('length: '+str(len(total)))
        print('tiktoken length:'+str(length))
        return length
    
    def cut(self):
        self.messages = [self.messages[0]] + [self.messages[-2:]]
    
    def execute(self):
        completion = self.openai.ChatCompletion.create(model="gpt-3.5-turbo", messages=self.messages)
        # Uncomment this to print out token usage each time, e.g.
        # {"completion_tokens": 86, "prompt_tokens": 26, "total_tokens": 112}
        # print(completion.usage)
        return completion.choices[0].message.content