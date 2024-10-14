import os


import os


import openai
from langchain_openai import ChatOpenAI
from langchain.schema import AIMessage, HumanMessage, SystemMessage

import datetime
from datetime import datetime, timedelta
import time

import pandas as pd
from geopy.distance import geodesic
from geopy.geocoders import Nominatim

from firebase_func import check_update

from AI_template import template_myState
from AI_template import template_txState
from AI_template import template_normal
from AI_template import templateJudgment

os.environ[ 'OPENAI_API_KEY'] = "INPUT YOUR API KEY"

    

#============= assume the talking time =============
def speech_timer(text):
    textSize = len(text)
    print(f"Speech timer On(Text size: {textSize}, {textSize/7} seconds),")
    time.sleep(len(text)/7)

def prompt_greeting():
    greeting = "대기모드입니다."
    print(greeting)
    #result = check_update(reqPath,3,1)
    #return userRequest_to_text()

def handle_exit():
    exit_message = "chatGPT를 종료합니다."
    print(exit_message)
    


#========================= get close Gas & Charge Station ========================= 
def get_closest_charging_station(gps_car):
    # https://www.data.go.kr/data/15102458/fileData.do
    # CSV 파일 경로
    file_path = '/home/pi/Documents/2024ESWContest_mobility_6013/Built_in_Cam/Generative_AI/charge_station.csv'
    
    # CSV 파일 로드
    charging_data = pd.read_csv(file_path, encoding='UTF-8')
    
    # 거리 계산 함수
    def calculate_distance(row):
        charging_station_coords = (row['위도'], row['경도'])
        return geodesic(gps_car, charging_station_coords).kilometers
    
    # 거리 계산
    charging_data['distance'] = charging_data.apply(calculate_distance, axis=1)
    
    # 가장 가까운 충전소 찾기
    closest_charging_station = charging_data.loc[charging_data['distance'].idxmin()]
    return closest_charging_station[['충전소명', '충전소주소', '위도', '경도', 'distance']]

# Nominatim 지오코더 초기화
geolocator = Nominatim(user_agent="geoapiExercises")

def geocode_address(address):
    try:
        location = geolocator.geocode(address)
        if location:
            return (location.latitude, location.longitude)
    except:
        return None

def get_closest_gas_station(gps_car):
    file_path = '/home/pi/Documents/2024ESWContest_mobility_6013/Built_in_Cam/Generative_AI/gas_station.csv'
    
    charging_data = pd.read_csv(file_path, encoding='UTF-8')

    # 거리 계산 함수
    def calculate_distance(row):
        charging_station_coords = (row['위도'], row['경도'])
        return geodesic(gps_car, charging_station_coords).kilometers

    # 거리 계산
    charging_data['distance'] = charging_data.apply(calculate_distance, axis=1)

    # 가장 가까운 주유소 찾기
    closest_gas_station = charging_data.loc[charging_data['distance'].idxmin()]
    return closest_gas_station[['주유소명', '위도', '경도', 'distance']]
#========================= GPT Function ========================= 
def process_chatgpt_request(chat, template, user_input):
    system_message = SystemMessage(content=template)
    user_message = HumanMessage(content=user_input)
    response = chat.invoke([system_message, user_message])
    return response.content

system_message_normal = SystemMessage(content=template_normal)
chatnormal = ChatOpenAI(model_name='gpt-3.5-turbo', temperature=0.5)

def chatgpt_response(prompt, history):
    messages = [
        system_message_normal,
        *history,
        HumanMessage(content=prompt)
    ]
    response = chatnormal.invoke(messages)
    return response

def chat_invoke(messages):
    return openai.ChatCompletion.create(
        model="gpt-3.5",
        messages=messages
    )




if __name__ == "__main__":
    print("this is conversation_func.py")
    