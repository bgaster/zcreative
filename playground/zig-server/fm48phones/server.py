import http.server
import ssl

def get_ssl_context(certfile, keyfile):
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    #ssl.PROTOCOL_TLSv1_2)
    # context = ssl.Context(ssl.TLSv1_2_METHOD)
    context.load_cert_chain(certfile, keyfile)
    context.set_ciphers("@SECLEVEL=1:ALL")
    return context


class MyHandler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers["Content-Length"])
        post_data = self.rfile.read(content_length)
        print(post_data.decode("utf-8"))

# server_address = ("192.168.1.18", 5000)
server_address = ("172.20.10.2", 5000)
httpd = http.server.HTTPServer(server_address, MyHandler)

print('%s' % (server_address,))

context = get_ssl_context("../cert/cert.pem", "../cert/key.pem")
httpd.socket = context.wrap_socket(httpd.socket, server_side=True)

httpd.serve_forever()
