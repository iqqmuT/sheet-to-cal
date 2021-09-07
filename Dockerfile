FROM ruby:2.7-alpine

# for compiling
RUN apk add --update --no-cache build-base tzdata

WORKDIR /code

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

CMD ["/usr/local/bin/ruby", "/code/run.rb"]
