if [ "$EUID" -ne 0 ]; then
  echo "run with sudo as it uses port 423"
  exit 1
fi

sed "s/{{ip}}/$(ipconfig getifaddr en0)/g" ./js/app.js.in > ./js/app.js
sed "s/{{ip}}/$(ipconfig getifaddr en0)/g" server.py.in > server.py
python3 server.py
