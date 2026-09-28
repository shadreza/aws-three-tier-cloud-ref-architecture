# Stage 1: build the Go program.
FROM golang:1.25-alpine AS build
WORKDIR /src

# Download modules first. Docker caches this step until go.mod or go.sum change.
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/uptime ./cmd/uptime
RUN mkdir -p /out/reports

# Stage 2: a tiny image with only the program. No shell, no package manager,
# and it runs as a normal user instead of root.
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/uptime /app/uptime
COPY --from=build --chown=nonroot:nonroot /out/reports /app/reports
WORKDIR /app
USER nonroot
EXPOSE 8080
ENTRYPOINT ["/app/uptime"]
CMD ["api"]
