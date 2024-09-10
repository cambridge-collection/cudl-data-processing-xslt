#! /bin/sh

curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip" &&
	unzip awscliv2.zip &&
	./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
