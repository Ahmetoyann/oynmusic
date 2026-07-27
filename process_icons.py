from PIL import Image
import os
import glob

def remove_black(image_path):
    img = Image.open(image_path).convert("RGBA")
    datas = img.getdata()
    
    # First, find bounding box of non-black pixels to crop the image
    min_x = img.width
    min_y = img.height
    max_x = 0
    max_y = 0
    
    for y in range(img.height):
        for x in range(img.width):
            item = img.getpixel((x, y))
            # Treat dark pixels as black
            if item[0] < 25 and item[1] < 25 and item[2] < 25:
                pass
            else:
                if x < min_x: min_x = x
                if y < min_y: min_y = y
                if x > max_x: max_x = x
                if y > max_y: max_y = y

    if max_x >= min_x and max_y >= min_y:
        pad = 20  # keep some padding
        min_x = max(0, min_x - pad)
        min_y = max(0, min_y - pad)
        max_x = min(img.width, max_x + pad)
        max_y = min(img.height, max_y + pad)
        img = img.crop((min_x, min_y, max_x, max_y))
        
    datas = img.getdata()
    newData = []
    
    for item in datas:
        # replace black with transparent
        if item[0] < 25 and item[1] < 25 and item[2] < 25:
            newData.append((item[0], item[1], item[2], 0))
        else:
            newData.append(item)
            
    img.putdata(newData)
    return img

folder = r"c:\Users\Ahmed\Music_App\assets\trendlerSayfasındakiHızlıMenuİkonları"
files = glob.glob(os.path.join(folder, "*.*"))

for f in files:
    if f.endswith('.jpeg') or f.endswith('.jpg') or f.endswith('.png'):
        if '_processed' in f:
            continue
        print(f"Processing {f}")
        try:
            new_img = remove_black(f)
            new_filename = f.rsplit('.', 1)[0] + "_processed.png"
            new_img.save(new_filename, "PNG")
            print(f"Saved {new_filename}")
        except Exception as e:
            print(f"Failed to process {f}: {e}")
