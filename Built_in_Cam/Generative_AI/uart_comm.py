import serial
import time

ser = serial.Serial('/dev/serial0', 9600, timeout=1)

def send_trigger():
    trigger = 'start'  
    ser.write(trigger.encode())  
    print("Trigger signal sent.")
    time.sleep(1)  

def receive_result(timeout=10):
    print("Waiting for result from Jetson Nano...")
    start_time = time.time()
    
    while True:
        if ser.in_waiting > 0:  
            result = ser.readline().decode().strip()  
            print(f"Received result: {result}")  
            return result 

        
        elapsed_time = time.time() - start_time
        if elapsed_time > timeout:
            print("Timeout: No result received.")
            return None  
        time.sleep(0.1)  

if __name__ == "__main__":
    send_trigger()  
    receive_result(timeout=10)  
