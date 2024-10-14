import os
import datetime
from datetime import datetime, timedelta
import time

def get_references(myCar_num):
    return {
        #============= myCar =============
        'myCar': (f'general/{myCar_num}'),
        'battery': (f'general/{myCar_num}/battery'),
        'trigger': (f'general/{myCar_num}/trigger'),
        'light' : (f'general/{myCar_num}/light'),
        #============= Service =============
        'Service': (f'general/{myCar_num}/Service'),
        'chargeStation': (f'general/{myCar_num}/Service/chargeStation'),
        'chargeStation_location': (f'general/{myCar_num}/Service/chargeStation/location'),
        'gasStation': (f'general/{myCar_num}/Service/gasStation'),
        'gasStation_location': (f'general/{myCar_num}/Service/gasStation/location'),
        'restArea': (f'general/{myCar_num}/Service/restArea'),
        'restArea_location': (f'general/{myCar_num}/Service/restArea/location'),
        
        #============= Location(Current location) =============
        'location': (f'general/{myCar_num}/location'),
        'location_lat': (f'general/{myCar_num}/location/lat'),
        'location_long': (f'general/{myCar_num}/location/long'),

        #============= problem(State&text) =============
        'problem': (f'general/{myCar_num}/problem'),
        'myState': (f'general/{myCar_num}/problem/myState'),
        'txState': (f'general/{myCar_num}/problem/txState'),
        


        #============= report(112&119 etc..) =============
        'report': (f'general/{myCar_num}/report'),

        #============= userRequest =============
        'userRequest': (f'general/{myCar_num}/userRequest'),
        'requestState': (f'general/{myCar_num}/userRequest/requestState'),
        'requestText': (f'general/{myCar_num}/userRequest/requestText'),
        'standbyState': (f'general/{myCar_num}/userRequest/standbyState')
        
    }


#============= just input the state =============
def state_input(target, state, input):
    new_State = input
    target.update({state: new_State})

#============= input the text & delete =============
def text_input(target, textState, input):
    new_Text = input
    target.update({textState: new_Text})
    target.update({textState: ""})

#============= check the data using Polling  =============
def check_update(ref, timeout=15, interval=1):
    initial_value = ref.get()
    start_time = time.time()

    while time.time() - start_time < timeout:
        current_value = ref.get()
        if current_value != initial_value:
            return current_value
        time.sleep(interval)
    
    return False

if __name__ == "__main__":
    print("this is firebase_func.py")



