import datetime
from datetime import datetime, timedelta
import time

import os


import openai
from langchain_openai import ChatOpenAI
from langchain.schema import AIMessage, HumanMessage, SystemMessage

import pandas as pd
from geopy.distance import geodesic
from geopy.geocoders import Nominatim

import firebase_admin
from firebase_admin import credentials
from firebase_admin import db
import json
import requests

import serial
import time
import threading

ser = serial.Serial('/dev/ttyACM0', 9600, timeout=1)
time.sleep(2)  

from uart_comm import send_trigger, receive_result

battery_value = 0
light_onoff = "ON/OFF"


cred = credentials.Certificate("INPUT YOUR CERTIFICATE FILE")#보안유지 중요
firebase_admin.initialize_app(cred,{'databaseURL':'INPUT YOUR DATABASE URL'})#보안유지 중요

from AI_template import template_myState
from AI_template import template_State
from AI_template import template_txState
from AI_template import templateJudgment
from AI_template import template_normal
from AI_template import templateRX
from AI_template import template_category_codes
from firebase_func import get_references
from firebase_func import state_input
from firebase_func import text_input
from firebase_func import  check_update
from conversation_func import speech_timer
from conversation_func import prompt_greeting
from conversation_func import handle_exit
from conversation_func import get_closest_charging_station
from conversation_func import get_closest_gas_station
from conversation_func import geocode_address
from conversation_func import process_chatgpt_request
from conversation_func import chatgpt_response


chat = ChatOpenAI(model_name='gpt-4o', temperature=0.5)

# API Key 설정
os.environ['OPENAI_API_KEY'] = "INPUT YOUR API KEY"#보안유지 중요
KAKAOMAP_API_KEY = 'INPUT YOUR API KEY'#보안유지 중요
# 차량 gps
gps_car = (37.5416, 127.0785)
myCar_num = "1311234"  
refs = get_references(myCar_num)
ref = db.reference('general')

def dbRef(dataLocation):
    return db.reference(dataLocation)


#========================= Car Info =============================
def read_arduino_data():
    global battery_value
    global light_onoff
    while True:
        if ser.in_waiting > 0:
            line = ser.readline().decode('utf-8').rstrip()

            data_parts = line.split(',')
            if len(data_parts) == 2:
                value = data_parts[0].strip()  
                status = data_parts[1].strip() 

                if value.isdigit():
                    battery_value = int(value)
                    
                    light_onoff = status
                
        time.sleep(0.01)


#========================= Battery & Fuel navigation func ========================= 
def battery_station():
    myText = "근처 충전소 정보를 알려드릴까요?"
    print(myText)
    state_input(dbRef(refs['userRequest']),"requestState","1")
    text_input(dbRef(refs['problem']),"myText",myText)# GPT Answer into Firebase Server
    speech_timer(myText)
    sys_msg판정 = SystemMessage(content=templateJudgment)
    user_input = check_update(dbRef(refs['requestText']),13,1)
    user_msg판정 = HumanMessage(content=user_input)
    print(user_input)
    aimsg판정 = chat.invoke([sys_msg판정, user_msg판정])
    myText = "알겠습니다."
    state_input(dbRef(refs['userRequest']),"requestState","0")
    print(myText)
    text_input(dbRef(refs['problem']),"myText",myText)
    
    general_location = (dbRef(refs['location_lat']).get(),dbRef(refs['location_long']).get())
    print(general_location)
    if 'yes' in aimsg판정.content:
        charging_station_info = get_closest_charging_station(general_location)
        myText = f"가장 가까운 충전소는 {charging_station_info['충전소명']}이며, 주소는 {charging_station_info['충전소주소']}입니다. 거리는 약 {charging_station_info['distance']:.2f} km입니다."
        print(myText)
        
        text_input(dbRef(refs['problem']),"rxText",myText)# GPT Answer into Firebase Serve
        
        speech_timer(myText)
        dbRef(refs['chargeStation']).update({'name': charging_station_info['충전소명']})
        dbRef(refs['chargeStation_location']).update({'lat': charging_station_info['위도']})
        dbRef(refs['chargeStation_location']).update({'long': charging_station_info['경도']})
        time.sleep(1)
        dbRef(refs['chargeStation']).update({'name': ""})
        dbRef(refs['chargeStation_location']).update({'lat': ""})
        dbRef(refs['chargeStation_location']).update({'long': ""})
    else:
        print("break")

def gas_station():
    myText = "근처 주유소 정보를 알려드릴까요?"
    print(myText)
    state_input(dbRef(refs['userRequest']),"requestState","1")
    speech_timer(myText)
    text_input(dbRef(refs['problem']),"myText",myText)# GPT Answer into Firebase Server
    sys_msg판정 = SystemMessage(content=templateJudgment)
    user_input = check_update(dbRef(refs['requestText']),13,1)
    user_msg판정 = HumanMessage(content=user_input)
    print(user_input)
    aimsg판정 = chat.invoke([sys_msg판정, user_msg판정])
    myText = "알겠습니다."
    state_input(dbRef(refs['userRequest']),"requestState","0")
    print(myText)
    text_input(dbRef(refs['problem']),"myText",myText)
    
    general_location = (dbRef(refs['location_lat']).get(),dbRef(refs['location_long']).get())
    print(general_location)
    if 'yes' in aimsg판정.content:
        charging_station_info = get_closest_gas_station(general_location)
        myText = f"가장 가까운 주유소는 {charging_station_info['주유소명']}이며, 거리는 약 {charging_station_info['distance']:.2f} km입니다."
        print(myText)
        text_input(dbRef(refs['problem']),"rxText",myText)# GPT Answer into Firebase Serve
        speech_timer(myText)
        dbRef(refs['gasStation']).update({'name': charging_station_info['주유소명']})
        dbRef(refs['gasStation_location']).update({'lat': charging_station_info['위도']})
        dbRef(refs['gasStation_location']).update({'long': charging_station_info['경도']})
        time.sleep(1)
        dbRef(refs['gasStation']).update({'name': ""})
        dbRef(refs['gasStation_location']).update({'lat': ""})
        dbRef(refs['gasStation_location']).update({'long': ""})
    else:
        print("break")
#========================= report func ========================= 
def report(AI_Text):
    institution = ["", ""]  
    if "119" in AI_Text:
        institution[0] = "소방서"
        institution[1] = "119"
    elif "112" in AI_Text:
        institution[0] = "경찰서"
        institution[1] = "112"
    else:
        institution[0] = "도로교통공사"
        institution[1] = "0800482000"
    
    myText = f"{institution[0]}에 신고하겠습니다."
    print(myText)
    text_input(dbRef(refs['problem']),"myText",myText)
    if institution[1] == "119":
        dbRef(refs['report']).update({'119': 1})
        dbRef(refs['report']).update({'119': 0})
    if institution[1] == "112":
        dbRef(refs['report']).update({'112': 1})
        dbRef(refs['report']).update({'112': 0})

    if institution[1] == "0800482000":
        dbRef(refs['report']).update({'0800482000': 1})
        dbRef(refs['report']).update({'0800482000': 0})
    
#========================= fireDetection & lightoffCar =============================
def fireDetction():
    print("fire detected")
    while True:
        if ser.in_waiting > 0:
            signal = ser.readline().decode().strip()  
            if signal == 'fire':
                text_input(dbRef(refs['problem']),"txState","fire")
                AI_text = "[txState, fire, unkown, 119]"
                myText = process_chatgpt_request(chat, template_txState, AI_text)
                print(myText)
                text_input(dbRef(refs['problem']),"txText",myText)
                report(AI_text)
                break    

def lighoffCar():
    print("detect lightoff car")
    while True:
        if ser.in_waiting > 0:
            signal = ser.readline().decode().strip()  
            if signal == 'off':
                text_input(dbRef(refs['problem']),"txState","fire")
                AI_text = "[txState, lightOff, unkown, unkown]"
                myText = process_chatgpt_request(chat, template_txState, AI_text)
                print(myText)
                text_input(dbRef(refs['problem']),"txText",myText)
                
                break    

#========================= LBS func ========================= 

def chatgpt_detect_category_code(chat, template, user_input):
    system_message = SystemMessage(content=template)
    user_message = HumanMessage(content=user_input)
    response = chat.invoke([system_message, user_message])
    return response.content

# 사용자 요청 분석하여 카테고리 코드 부여
def detect_category_code(user_request):
    for keyword, code in category_codes.items():
        if re.search(keyword, user_request):
            return code
    return None  

# 카카오 API로 장소 검색 요청 함수
def search_places_by_category(category_code, general_location_lat, general_location_long):
    url = 'https://dapi.kakao.com/v2/local/search/category.json'
    headers = {"Authorization": f"KakaoAK {KAKAOMAP_API_KEY}"}
    params = {
        'category_group_code': category_code,
        'x': general_location_long,
        'y': general_location_lat,
        'radius': 2000, # 범위지정 (단위:m)
        'sort': 'distance',  # 거리순으로 정렬 'distance', 정확도순으로 정렬 'accuracy', 별점순 정렬 기능은 없음.
        'page': 1,
        'size': 10  # 결과 개수
    }
    
    response = requests.get(url, headers=headers, params=params)
    data = response.json()
    
    # 결과 출력
    if 'documents' in data:
        return data['documents']
    else:
        return None

#========================= main func ========================= 
def run_mainAI():
    print("main start")
    chat = ChatOpenAI(model_name='gpt-3.5-turbo', temperature=0.5)
    

    while True:
        
        print("Checking...(Wating Mode)")
        

        state_input(dbRef(refs['userRequest']),"requestState","0")
        while True:
            state_input(dbRef(refs['userRequest']),"standbyState","1")
        


            global battery_value
            global light_onoff
            dbRef(refs['myCar']).update({'light': light_onoff})
            dbRef(refs['myCar']).update({'battery': battery_value})
            if dbRef(refs['battery']).get() <= 30:

                prompt = "배터리가 일정수준 이하입니다. 충전이 필요합니다."
                print(prompt)
                text_input(dbRef(refs['problem']),"rxText",prompt)# GPT Answer into Firebase Serve
                speech_timer(prompt)
                print("this is lowbattery")
                battery_station()


            if dbRef(refs['light']).get() == "OFF":
             
                prompt = "라이트가 꺼져있습니다. AUTO 상태 혹은 라이트를 켜주세요"
                print(prompt)
                text_input(dbRef(refs['problem']),"rxText",prompt)# GPT Answer into Firebase Serve
                speech_timer(prompt)

            #=========================check the recived data=========================       
            if dbRef(refs['trigger']).get() == "on":
                print("Trigger On")
                txState = dbRef(refs['txState']).get()
                print("txstate:", txState)
                dbRef(refs['myCar']).update({'trigger': 'off'})
                dbRef(refs['problem']).update({'txState': ""})
                print("run subprocess")
                rxText = process_chatgpt_request(chat, templateRX, txState)
                print(rxText)
                text_input(dbRef(refs['problem']),"rxText",rxText)
                
                

            else :
                result = check_update(dbRef(refs['requestText']),5,1)
                print(result)
                if result != False:

                    user_input = dbRef(refs['requestText']).get()
                    break

        print(user_input)
        state_input(dbRef(refs['userRequest']),"standbyState","1")
        terms = ["여봐라", "여보라", "여바라","여봐라","GP", "PPT","GPT","PT","도와줘"]#호출 AI  이름 커스텀 가능


        if  any(term in user_input for term in terms):
            print("AI Called")

            while True:
                prompt = "네 무엇을 도와드릴까요?"
                print(prompt)
                text_input(dbRef(refs['problem']),"rxText",prompt)# GPT Answer into Firebase Server
                state_input(dbRef(refs['userRequest']),"requestState","1")
                speech_timer(prompt)
                user_input = check_update(dbRef(refs['requestText']),13,1)# 시간간격 수정가능
                state_input(dbRef(refs['userRequest']),"requestState","0")
                print(user_input)

                if user_input == False:
                    prompt = "대기모드로 돌아갑니다"
                    print(prompt)
                    text_input(dbRef(refs['problem']),"rxText",prompt)
                    break

                AI_text = process_chatgpt_request(chat, template_State, user_input)
                print(AI_text)



                if 'txState' in AI_text:
                    print("This is txState")
                    pared_text =  [item.strip() for item in AI_text[1:-1].split(',')]
                    text_input(dbRef(refs['problem']),"txState",pared_text[1])
                    myText = process_chatgpt_request(chat, template_txState, AI_text)
                    print(myText)
                    text_input(dbRef(refs['problem']),"txText",myText)

                    send_trigger()
                    OCR_car = receive_result()

                    if OCR_car == None:
                        prompt = "전방차량 인식에 실패했습니다."
                        print(prompt)
                        text_input(dbRef(refs['problem']),"rxText",prompt)
                    
                    else:
                        refs_other = get_references(OCR_car)
                        text_input(dbRef(refs_other['problem']),"txState",pared_text[1])
                        report(AI_text)
                        
                    break
                    
                elif 'myState' in AI_text:
                    pared_text =  [item.strip() for item in AI_text[1:-1].split(',')]
                    text_input(dbRef(refs['problem']),"myState",pared_text[1])
                    myText = process_chatgpt_request(chat, template_myState, AI_text)
                    print(myText)
                    text_input(dbRef(refs['problem']),"myText",myText)
                    speech_timer(myText)

                    if 'lowBattery' in AI_text:
                        print("this is lowbattery")
                        battery_station()

                    elif 'fuelShortage':
                        gas_station()

                    else:
                        report(AI_text)

                    break

                elif 'normalState' in AI_text:
                    print("This is normalState")
                    historynormal = []
                    nmText = process_chatgpt_request(chat, template_normal, user_input)  # GPT 응답
                    print(nmText)
                    text_input(dbRef(refs['problem']), "nmText", nmText)
                    speech_timer(nmText)
                    state_input(dbRef(refs['userRequest']), "requestState", "1")
                    
                    # 사용자 발화와 GPT 응답을 대화 히스토리에 저장
                    historynormal.append(HumanMessage(content=user_input))
                    historynormal.append(AIMessage(content=nmText))
                    
                    
                    while True:
                        result = check_update(dbRef(refs['requestText']), 8, 1)
                        print(result)
                        
                        if result != False:
                            user_input = dbRef(refs['requestText']).get()
                            state_input(dbRef(refs['userRequest']), "requestState", "0")
                        elif result == False:
                            print("no answer so quit")
                            state_input(dbRef(refs['userRequest']), "requestState", "0")
                            break
                        
                        # "그만", "멈춰", "종료"라는 발화가 들어오면 종료
                        if '그만' in user_input or '멈춰' in user_input or '종료' in user_input:
                            
                            state_input(dbRef(refs['userRequest']), "requestState", "0")
                            break
                        
                        
                        nmText = process_chatgpt_request(chat, template_normal, user_input)  # GPT 응답
                        print(nmText)
                        text_input(dbRef(refs['problem']), "nmText", nmText)
                        speech_timer(nmText)
                        state_input(dbRef(refs['userRequest']), "requestState", "1")
                        
                        # 대화 히스토리 업데이트
                        historynormal.append(HumanMessage(content=user_input))
                        historynormal.append(AIMessage(content=nmText))
                        
                        # 판정 로직 (이전 대화에서 판정하는 부분 유지)
                        sys_msg판정 = SystemMessage(content=templateJudgment)
                        user_msg판정 = HumanMessage(content=user_input)
                        aimsg판정 = chat.invoke([sys_msg판정, user_msg판정])
                        
                        # 판정 결과에 따라 종료
                        if 'no' in aimsg판정.content:
                            print("you said no so quit")
                            state_input(dbRef(refs['userRequest']), "requestState", "0")
                            break

                    break  
                   
                elif 'lbsState' in AI_text: 
                    print(user_input)
                    selected_code = chatgpt_detect_category_code(chat, template_category_codes, user_input)

                    
                    place_info = []

                    if selected_code:
                        places = search_places_by_category(selected_code, dbRef(refs['location_lat']).get(),dbRef(refs['location_long']).get())
                        if places:
                            current_datetime = datetime.now()
                            date_str = current_datetime.strftime('%Y%m%d')  # ex: '2024_10_06'
                            time_str = current_datetime.strftime('%H%M%S')  # ex: '16:17:00'
                            for idx, place in enumerate(places, 1):
                                
                                if idx > 3: 
                                    break
                                name = place['place_name']
                                category = place['category_name']
                                place_url = place['place_url']
                                place_latitude = place['y'] # 위도
                                place_longitude = place['x'] # 경도
                                print(f"{idx}. **{name}** ({category})")
                                print(f"[카카오맵 링크]({place_url})")
                                path = f'{myCar_num}/LBS/{date_str}/{time_str}/{idx}'
                                data = {name: place_url}
                                ref.child(path).set(data)   
                                place_info.append([name, category, place_url, place_latitude, place_longitude ])
                            prompt = f"첫 번째 {place_info[0][0]} 두 번째 {place_info[1][0]} 세 번째 {place_info[2][0]} 몇번째로 안내할까요?          "
                            print(prompt)
                            text_input(dbRef(refs['problem']),"rxText",prompt)# GPT Answer into Firebase Server
                            prompt = f"첫 번째 {place_info[0][0]} 두 번째 {place_info[1][0]} 세 번째 {place_info[2][0]} 몇번째로 안내할까요?"
                            speech_timer(prompt)
                            state_input(dbRef(refs['userRequest']),"requestState","1")
                            result = check_update(dbRef(refs['requestText']),10,1)
                            print(result)
                            state_input(dbRef(refs['userRequest']),"requestState","0")
                            if result != False:

                                user_input = dbRef(refs['requestText']).get()
                                
                            else:
                                prompt = "대답이 없어서 종료합니다"
                                print(prompt)
                                text_input(dbRef(refs['problem']),"rxText",prompt)# GPT Answer into Firebase Server
                                speech_timer(prompt)

                            print(user_input)
                            
                            term_1 = ["첫번째", "첫", "일","첫번째꺼","첫 번"] 
                            term_2 = ["두번째", "두", "이","두번째꺼","두 번"] 
                            term_3 = ["세번째", "세", "삼","세번째꺼","세 번"] 


                            if  any(term in user_input for term in term_1):
                                dbRef(refs['chargeStation']).update({'name': place_info[0][0]})
                                dbRef(refs['chargeStation_location']).update({'lat':  place_info[0][3]})
                                dbRef(refs['chargeStation_location']).update({'long':  place_info[0][4]})
                                time.sleep(1)
                                dbRef(refs['chargeStation']).update({'name': ""})
                                dbRef(refs['chargeStation_location']).update({'lat': ""})
                                dbRef(refs['chargeStation_location']).update({'long': ""})

                            elif  any(term in user_input for term in term_2):
                                dbRef(refs['chargeStation']).update({'name': place_info[1][0]})
                                dbRef(refs['chargeStation_location']).update({'lat':  place_info[1][3]})
                                dbRef(refs['chargeStation_location']).update({'long':  place_info[1][4]})
                                time.sleep(1)
                                dbRef(refs['chargeStation']).update({'name': ""})
                                dbRef(refs['chargeStation_location']).update({'lat': ""})
                                dbRef(refs['chargeStation_location']).update({'long': ""})

                            elif  any(term in user_input for term in term_3):
                                dbRef(refs['chargeStation']).update({'name': place_info[2][0]})
                                dbRef(refs['chargeStation_location']).update({'lat':  place_info[2][3]})
                                dbRef(refs['chargeStation_location']).update({'long':  place_info[2][4]})
                                time.sleep(1)
                                dbRef(refs['chargeStation']).update({'name': ""})
                                dbRef(refs['chargeStation_location']).update({'lat': ""})
                                dbRef(refs['chargeStation_location']).update({'long': ""})

                            else:
                                prompt = "대답을 정확하게 이해하지 못했어요"
                                print(prompt)
                                text_input(dbRef(refs['problem']),"rxText",prompt)# GPT Answer into Firebase Server
                                speech_timer(prompt)

                            break
                        else:
                            print("카테고리 코드를 선택할 수 없는 사용자 요청")
                            break                   
                    break                                          
                            

if __name__ == "__main__":
    thread_1 = threading.Thread(target=read_arduino_data)
    thread_2 = threading.Thread(target=run_mainAI)

    # 스레드 실행
    thread_1.start()
    thread_2.start()

    # 메인 스레드가 두 개의 스레드가 끝날 때까지 기다림
    thread_1.join()
    thread_2.join()