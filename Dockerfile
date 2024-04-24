FROM --platform=linux/amd64 ruby:3.2.2

RUN sh -c 'echo "deb [arch=amd64] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list'
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -

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
    nodejs \
    google-chrome-stable

RUN useradd -ms /bin/bash demat-social

# update with the version of Chrome that you are using
RUN curl -fsSL https://storage.googleapis.com/chrome-for-testing-public/$(google-chrome-stable --version | cut -d ' ' -f 3)/linux64/chromedriver-linux64.zip -o chromedriver.zip \
    && unzip chromedriver.zip \
    && mv chromedriver-linux64/chromedriver /usr/bin/chromedriver \
    && rm chromedriver.zip \
    && rm -fr chromedriver-linux64 \
    && chmod +x /usr/bin/chromedriver \
    && chown demat-social:demat-social /usr/bin/chromedriver

USER demat-social
RUN mkdir /home/demat-social/app
WORKDIR /home/demat-social/app

COPY --chown=demat-social:demat-social --chmod=770 . /home/demat-social/app

RUN bundle install --jobs 20 --retry 5
RUN yarn install

EXPOSE $PORT

CMD ["/bin/bash", "-c", "bin/rails s -b 0.0.0.0 -p $PORT"]
