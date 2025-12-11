sed "s/{{ip}}/$(ipconfig getifaddr en0)/g" ./js/app.js.in > ./js/app.js
sed "s/{{ip}}/$(ipconfig getifaddr en0)/g" server.py.in > server.py
python3 server.py
