cmake_minimum_required(VERSION 3.10)
project(noray-server)

# Find required packages
find_package(OpenSSL REQUIRED)
find_package(Opus REQUIRED)

# Add the executable
add_executable(noray-server
	src/main.cpp
	src/voip_server.cpp
	src/voip_server.h
)

# Link against required libraries
target_link_libraries(noray-server PRIVATE
	OpenSSL::SSL
	OpenSSL::Crypto
	opus
) 
