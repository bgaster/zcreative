# sed "s/{{ip}}/$(ipconfig getifaddr en0)/g" index.html.in > index.html
sed "s/{{ip}}/$(ipconfig getifaddr en0)/g" server.py.in > server.py
python3 server.py
