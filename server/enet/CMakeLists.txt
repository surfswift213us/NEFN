cmake_minimum_required(VERSION 3.10)
project(enet-server)

# Find ENet package
find_package(ENet REQUIRED)

# Add the executable
add_executable(enet-server
	src/main.cpp
	src/server.cpp
	src/server.h
)

# Link against ENet
target_link_libraries(enet-server PRIVATE enet) 
