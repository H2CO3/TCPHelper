/*
  tcp_connect.h
  TCP connect helper
  
  Created by Árpád Goretity on 30/12/2011.
  Released into the public domain,
  with no warranty of any kind
*/

#ifndef __TCPCONNECT_H__
#define __TCPCONNECT_H__

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <pthread.h>


/*
  Function type to be invoked in separate threads whenever tcpconnect_persistent_server() encounters
  a new incoming connection. It will be supplied
  a pointer to a socket file descriptor.
  This pointer is to be free()'d after use.
*/

typedef void (*tcpconnect_server_fn_t)(int *fdptr);

/*
  Callback function used by tcpconnect_persistent_server() to notify about creation of new server threads.
  This function must not perform heavy computation or otherwise time consuming operations.
  tid is a pthread_t containing info about the newly spawned thread.
  sockfd must not be read from nor written to, it's there only in order the callback to know
  which socket descriptor belongs to which thread.
*/

typedef void (*tcpconnect_callback_fn_t)(pthread_t tid, int sockfd);

/*
  Returns a socket file descriptor,
  from/to which one can read() or write().
  To be close()'d after use.
  Useful for clients wanting to connect to a specific server
  The server must be already listening using connect_to_client().
  This function does not return until a server
  accepted the connection on the specified port.
*/

int tcpconnect_start_client(const char *hostname, const char *port);

/*
  Returns a socket file descriptor,
  from/to which one can read() or write().
  To be close()'d after use.
  Useful for servers wanting to accept an incoming
  connection from any client.
  This function does not return until a client
  has successfully connected on the specified port.
*/

int tcpconnect_start_server(const char *port);

/*
  Returns a file descriptor, which can be supplied to tcpconnect_accept_single in order to retrieve
  a read()able-write()able socket file descriptor.
*/

int tcpconnect_start_multiple(const char *port);

/*
  Takes a socket file descriptor returned by tcpconnect_start_multiple(). This blocks until a
  client connects to the other end of the socket.
  Returns a readable-writable socket file descriptor on success or negative on error.
*/

int tcpconnect_accept_single(int stubfd);

#endif /* !__TCPCONNECT_H__ */

