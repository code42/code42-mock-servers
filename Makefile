IMAGE_TAG = c42/mock-microservice-endpoints:1.0

all:: start

start::
	docker-compose up --build

stop::
	docker-compose down --rmi all
