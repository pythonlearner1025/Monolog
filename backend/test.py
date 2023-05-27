from prompts import *
from utils import ChatBot
import datetime
import os

def mark(): return '*'*10

def stamp():
    current_datetime = datetime.datetime.now()
    current_day = current_datetime.day
    current_hour = current_datetime.hour
    current_minute = current_datetime.minute
    return f'_{current_day}:{current_hour}:{current_minute}'

if __name__ == '__main__':
    TS = os.path.join(os.getcwd(), 'transcripts')
    OS = os.path.join(os.getcwd(), 'outs')
    lengths = ['short', 'medium', 'long']
    formats = ['bullet-point']
    styles = ['casual', 'professional']

    for f in os.listdir(TS):
        print(mark() + f'generating for f' + mark())
        fpath = os.path.join(TS, f)
        with open(fpath, 'r') as file:
            transcript = file.read()
        print(f'transcript: {transcript}')
        for length in lengths:
            for format in formats:
                for style in styles:
                    print(mark()+f'output'+mark())
                    print(f'length: {length}')
                    print(f'format: {format}')
                    print(f'style: {style}')
                    action_sys = get_action(length, format, style)
                    summary_sys = get_summary(length, format, style)
                    action_bot = ChatBot(system=action_sys)
                    summary_bot = ChatBot(system=summary_sys)

                    action = action_bot(transcript)
                    summary = summary_bot(transcript)
                    print(f'--ACTION--\n{action}')
                    print()
                    print(f'--SUMMARY--\n{summary}')

                    for out in zip(['action', 'summary'], [action, summary]):
                        name = os.path.join(OS, ','.join([os.path.splitext(f)[0]+'_'+out[0], length, format, style]))
                        with open(name+stamp()+'.txt', 'w') as file:
                            file.write(out[1])

