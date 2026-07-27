import os
import glob

directory = r'c:\Users\Ahmed\Music_App\lib'
old_string = 'assets/trendlerSayfasındakiHızlıMenuİkonları'
new_string = 'assets/trend_menu_icons'

for filepath in glob.iglob(directory + '/**/*.dart', recursive=True):
    with open(filepath, 'r', encoding='utf-8') as file:
        content = file.read()
    if old_string in content:
        content = content.replace(old_string, new_string)
        with open(filepath, 'w', encoding='utf-8') as file:
            file.write(content)
        print(f'Updated {filepath}')
