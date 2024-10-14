import cv2
import numpy as np

haar_cascade = 'cars_tail_light.xml'
taillight_cascade = cv2.CascadeClassifier(haar_cascade)

def process_video(video_path, initial_threshold=80):
    cap = cv2.VideoCapture(video_path)
    
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = int(cap.get(cv2.CAP_PROP_FPS))
    
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter('./lightOff.mp4', fourcc, fps, (width, height))
    
    
    threshold = initial_threshold
    
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
        

        taillight = taillight_cascade.detectMultiScale(frame, 1.1, 3)


        for (x, y, w, h) in taillight:
            cv2.rectangle(frame, (x,y), (x+w, y+h), (0,0,255), 2)
        
        left_roi = frame[taillight[0][1]:taillight[1][1], taillight[0][0]:taillight[1][0]]
        right_roi = frame[taillight[0][1]:taillight[1][1], taillight[0][0]:taillight[1][0]]
        
        left_brightness = np.mean(left_roi)
        right_brightness = np.mean(right_roi)
        
        left_status = 1 if left_brightness > threshold else 0
        right_status = 1 if right_brightness > threshold else 0
        
        left_color = (0, 255, 0) if left_status == 1 else (0, 0, 255)
        right_color = (0, 255, 0) if right_status == 1 else (0, 0, 255)
        
        
        cv2.putText(frame, f"Left: {left_status} ({left_brightness:.2f})", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, left_color, 2)
        cv2.putText(frame, f"Right: {right_status} ({right_brightness:.2f})", (width-280, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, right_color, 2)
        cv2.putText(frame, f"Threshold: {threshold}", (10, height - 20), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
        
        out.write(frame)
            
        cv2.imshow('Frame', frame)
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q'):
            break
        elif key == ord('u'):  # 'u' - increasing threshold 
            threshold += 5
        elif key == ord('d'):  # 'd' - decreasing threshold
            threshold -= 5
        
        print(f"Left brightness: {left_brightness:.2f}, Right brightness: {right_brightness:.2f}")
    
    cap.release()
    out.release()
    cv2.destroyAllWindows()

video_path = 'ghost_car.mp4'
process_video(video_path, initial_threshold=80)