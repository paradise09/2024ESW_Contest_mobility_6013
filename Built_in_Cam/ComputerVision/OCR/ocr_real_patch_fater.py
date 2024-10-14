import cv2
import numpy as np
import pytesseract
import serial
import time
from process_image_module import process_image  

ser = serial.Serial('/dev/ttyTHS1', 9600, timeout=1)

def find_chars(contour_list):
    MAX_DIAG_MULTIPLYER = 5
    MAX_ANGLE_DIFF = 12.0
    MAX_AREA_DIFF = 0.5
    MAX_WIDTH_DIFF = 0.8
    MAX_HEIGHT_DIFF = 0.2
    MIN_N_MATCHED = 3

    matched_result_idx = []
    for d1_idx, d1 in enumerate(contour_list):
        matched_contours_idx = []
        for d2_idx, d2 in enumerate(contour_list):
            if d1_idx == d2_idx:
                continue

            dx = abs(d1['cx'] - d2['cx'])
            dy = abs(d1['cy'] - d2['cy'])

            diagonal_length1 = np.sqrt(d1['w'] ** 2 + d1['h'] ** 2)

            distance = np.linalg.norm(np.array([d1['cx'], d1['cy']]) - np.array([d2['cx'], d2['cy']]))
            if dx == 0:
                angle_diff = 90
            else:
                angle_diff = np.degrees(np.arctan(dy / dx))
            area_diff = abs(d1['w'] * d1['h'] - d2['w'] * d2['h']) / (d1['w'] * d1['h'])
            width_diff = abs(d1['w'] - d2['w']) / d1['w']
            height_diff = abs(d1['h'] - d2['h']) / d1['h']

            if distance < diagonal_length1 * MAX_DIAG_MULTIPLYER \
                    and angle_diff < MAX_ANGLE_DIFF and area_diff < MAX_AREA_DIFF \
                    and width_diff < MAX_WIDTH_DIFF and height_diff < MAX_HEIGHT_DIFF:
                matched_contours_idx.append(d2_idx)

        if len(matched_contours_idx) < MIN_N_MATCHED:
            continue

        matched_result_idx.append(matched_contours_idx)

    return matched_result_idx

def process_image(img_ori):
    gray_img = cv2.cvtColor(img_ori, cv2.COLOR_BGR2GRAY)
    
    # 이미지 크기 축소
    height, width = gray_img.shape
    gray_img = cv2.resize(gray_img, (width // 2, height // 2))

    img_thresh = cv2.adaptiveThreshold(
        gray_img,
        maxValue=255.0,
        adaptiveMethod=cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        thresholdType=cv2.THRESH_BINARY_INV,
        blockSize=19,
        C=9
    )

    contours, _ = cv2.findContours(
        img_thresh,
        mode=cv2.RETR_LIST,
        method=cv2.CHAIN_APPROX_SIMPLE
    )

    contours_dict = []
    for contour in contours:
        x, y, w, h = cv2.boundingRect(contour)
        contours_dict.append({
            'x': x,
            'y': y,
            'w': w,
            'h': h,
            'cx': x + (w / 2),
            'cy': y + (h / 2)
        })

    MIN_AREA = 80
    MIN_WIDTH, MIN_HEIGHT = 2, 8
    MIN_RATIO, MAX_RATIO = 0.25, 1.0

    possible_contours = [
        d for d in contours_dict
        if MIN_AREA < d['w'] * d['h'] < 1000
        and MIN_WIDTH < d['w'] < 200
        and MIN_HEIGHT < d['h'] < 200
        and MIN_RATIO < d['w'] / d['h'] < MAX_RATIO
    ]

    result_idx = find_chars(possible_contours)

    matched_result = [
        [possible_contours[idx] for idx in idx_list]
        for idx_list in result_idx
    ]

    PLATE_WIDTH_PADDING = 1.3
    PLATE_HEIGHT_PADDING = 1.5
    MIN_PLATE_RATIO = 3
    MAX_PLATE_RATIO = 10

    plate_imgs = []
    plate_infos = []

    for matched_chars in matched_result:
        sorted_chars = sorted(matched_chars, key=lambda x: x['cx'])

        plate_cx = (sorted_chars[0]['cx'] + sorted_chars[-1]['cx']) / 2
        plate_cy = (sorted_chars[0]['cy'] + sorted_chars[-1]['cy']) / 2
        
        plate_width = (sorted_chars[-1]['x'] + sorted_chars[-1]['w'] - sorted_chars[0]['x']) * PLATE_WIDTH_PADDING
        
        sum_height = sum(d['h'] for d in sorted_chars)
        plate_height = int(sum_height / len(sorted_chars) * PLATE_HEIGHT_PADDING)
        
        triangle_height = sorted_chars[-1]['cy'] - sorted_chars[0]['cy']
        triangle_hypotenus = np.linalg.norm(
            np.array([sorted_chars[0]['cx'], sorted_chars[0]['cy']]) - 
            np.array([sorted_chars[-1]['cx'], sorted_chars[-1]['cy']])
        )
        
        angle = np.degrees(np.arcsin(triangle_height / triangle_hypotenus))
        
        rotation_matrix = cv2.getRotationMatrix2D(center=(plate_cx, plate_cy), angle=angle, scale=1.0)
        
        img_rotated = cv2.warpAffine(img_thresh, M=rotation_matrix, dsize=(width // 2, height // 2))
        
        img_cropped = cv2.getRectSubPix(
            img_rotated, 
            patchSize=(int(plate_width), int(plate_height)), 
            center=(int(plate_cx), int(plate_cy))
        )
        
        if MIN_PLATE_RATIO < img_cropped.shape[1] / img_cropped.shape[0] < MAX_PLATE_RATIO:
            plate_imgs.append(img_cropped)
            plate_infos.append({
                'x': int(plate_cx - plate_width / 2) * 2,  # 원본 이미지 크기로 복원
                'y': int(plate_cy - plate_height / 2) * 2,
                'w': int(plate_width) * 2,
                'h': int(plate_height) * 2
            })

    longest_idx, longest_text = -1, 0
    plate_chars = []

    for i, plate_img in enumerate(plate_imgs):
        plate_img = cv2.resize(plate_img, dsize=(0, 0), fx=1.6, fy=1.6)
        _, plate_img = cv2.threshold(plate_img, thresh=0.0, maxval=255.0, type=cv2.THRESH_BINARY | cv2.THRESH_OTSU)
        
        # Tesseract OCR 설정
        config = r'--oem 3 --psm 7 -c tessedit_char_whitelist=0123456789가나다라마바사아자차카타파하'
        chars = pytesseract.image_to_string(plate_img, lang='kor', config=config)

        result_chars = ''.join(c for c in chars if ord('가') <= ord(c) <= ord('힣') or c.isdigit())
        
        plate_chars.append(result_chars)

        if len(result_chars) > longest_text:
            longest_idx = i
            longest_text = len(result_chars)

    if longest_idx == -1:
        return "Can't find number plate", None
    else:
        return plate_chars[longest_idx], plate_infos[longest_idx]

def main():
    cap = cv2.VideoCapture(0)
    while True:
        if ser.in_waiting > 0:
            trigger_signal = ser.readline().decode().strip()
            if trigger_signal == 'start':  
                print("Trigger received, starting process_image()")
                
                ret, frame = cap.read()
                if not ret:
                    print("Frame Failed")
                    break

               
                result, plate_info = process_image(frame)

                
                ser.write(result.encode())
                print(f"Sent result: {result}")
                time.sleep(1)  

                
                cv2.putText(frame, result, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
                if plate_info:
                    cv2.rectangle(frame, (plate_info['x'], plate_info['y']),
                                  (plate_info['x'] + plate_info['w'], plate_info['y'] + plate_info['h']),
                                  (0, 255, 0), 2)

                cv2.imshow('WebCam', frame)

                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break
            else:
                print(f"Unknown signal: {trigger_signal}")

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()
