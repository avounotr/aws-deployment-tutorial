FROM nginx:latest

#  default conf for proxy service
COPY ./default.conf /etc/nginx/conf.d/default.conf
RUN chmod 777 /etc/nginx/conf.d/default.conf

# Allow us to customize the entrypoint of the image.
RUN sed -i "s/PLACEHOLDER_VHOST/http:\/\/18.195.73.33/g" "/etc/nginx/conf.d/default.conf"

RUN cat /etc/nginx/conf.d/default.conf
