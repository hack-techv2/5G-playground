### CTFd code
# Install Docker via Snap
sudo snap install docker
# Clone the CTFd repository into the current working directory
git clone https://github.com/CTFd/CTFd.git ../CTFd
# Copy custom configuration to the CTFd folder (change nginx port from 80 to 8080)
rm ../CTFd/docker-compose.yml
cp docker-compose.yml ../CTFd/docker-compose.yml
# Generate a 64-character secret key and store it in the .ctfd_secret_key file in the CTFd directory
head -c 64 /dev/urandom > ../CTFd/.ctfd_secret_key
# Change directory to the CTFd folder in the current working directory
cd ../CTFd
# Start CTFd using Docker Compose
sudo docker-compose up -d

