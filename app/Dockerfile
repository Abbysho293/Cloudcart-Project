# Simple production-ready Node image
FROM node:18-alpine

WORKDIR /usr/src/app
COPY package.json package-lock.json* ./
RUN npm install --production || npm install --production --legacy-peer-deps

COPY . .

ENV PORT=3000
EXPOSE 3000

CMD ["npm", "start"]
