FROM --platform=linux/amd64/v2 ruby:3.2.2

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /etc/apt/trusted.gpg.d/yarn.gpg
RUN echo "deb [signed-by=/etc/apt/trusted.gpg.d/yarn.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

RUN apt-get update && apt-get install -y \
    libcurl3-dev \
    libpq-dev \
    zlib1g-dev \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    libnss3 \
    zip \
    yarn \
    nodejs

RUN useradd -ms /bin/bash demat-social

RUN mkdir /opt/ds
WORKDIR /opt/ds

COPY . /opt/ds

RUN cp ./docker/chromedriver_124_0_6367_91 /usr/bin/chromedriver \
    && chmod +x /usr/bin/chromedriver \
    && unzip ./docker/chrome-linux124-0-6367-91.zip -d ./docker \
    && mkdir -p /opt/chrome \
    && mv ./docker/chrome-linux64/* /opt/chrome \
    && rm -rf ./docker/chrome-linux64 \
    && ln -s /opt/chrome/chrome /usr/bin/chrome \
    && chmod +x /opt/chrome/chrome

RUN yarn install
RUN bundle install --jobs 20 --retry 5

RUN chown -R demat-social:demat-social /opt/ds \
    && chmod -R 755 /opt/ds

USER demat-social

EXPOSE $PORT

CMD ["/bin/bash", "-c", "bin/rails s -b 0.0.0.0 -p $PORT"]
