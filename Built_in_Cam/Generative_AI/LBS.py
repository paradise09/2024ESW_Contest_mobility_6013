
import os

import openai
import requests
from langchain_openai import ChatOpenAI
from langchain.schema import AIMessage, HumanMessage, SystemMessage

import re
import requests

# chatGPT API Key 설정
os.environ["OPENAI_API_KEY"] = "INPUT YOUR API KEY"

# 카카오 API 키 설정, Rest API
KAKAOMAP_API_KEY = 'INPUT YOUR API KEY'


# 카테고리 코드와 키워드 매칭
template_category_codes = """
chatGPT는 본인의 판단에 따라 사용자의 요청을 분석하여 다음과 같은 코드를 부여하여 출력한다.
chatGPT는 코드만 단답으로 답변하면 된다. 예시) MT1

대형마트 -> MT1
편의점 -> CS2
어린이집, 유치원 -> PS3
학교 -> SC4
학원 -> AC5
주차장 -> PK6
주유소, 충전소 -> OL7
지하철역 -> SW8
은행 -> BK9
문화시설 -> CT1
중개업소 -> AG2
공공기관 -> PO3
관광명소 -> AT4
숙박 -> AD5
음식점 -> FD6
카페 -> CE7
병원 -> HP8
약국 -> PM9

"""

# 카테고리 코드와 키워드 매칭


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
    return None  # 해당하는 카테고리가 없을 때 -> 이 부분에서 기존 코드로 넘어가게 수정하면 될 것 같습니다.

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

# 차량 gps
general_location_lat = 37.5416
general_location_long = 127.0785

# chatGPT 설정
chat = ChatOpenAI(model_name='gpt-4o', temperature=0.5)

# 사용자 요청
user_request = "나 잠 잘 곳 추천좀"

# 카테고리 코드 자동 선택
selected_code = chatgpt_detect_category_code(chat, template_category_codes, user_request)

# 검색 실행 및 결과 출력

if selected_code:
    places = search_places_by_category(selected_code, general_location_lat, general_location_long)
    if places:
        for idx, place in enumerate(places, 1):
            name = place['place_name']
            category = place['category_name']
            place_url = place['place_url']
            print(f"{idx}. **{name}** ({category})")
            print(f"[카카오맵 링크]({place_url})")
else:
    print("카테고리 코드를 선택할 수 없는 사용자 요청")
