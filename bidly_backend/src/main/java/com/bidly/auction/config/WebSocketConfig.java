package com.bidly.auction.config;

import com.bidly.common.security.JwtTokenProvider;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.util.StringUtils;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

import java.util.Collections;
import java.util.UUID;

@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    private static final Logger log = LoggerFactory.getLogger(WebSocketConfig.class);

    private final JwtTokenProvider jwtTokenProvider;

    public WebSocketConfig(JwtTokenProvider jwtTokenProvider) {
        this.jwtTokenProvider = jwtTokenProvider;
    }

    @Override
    public void configureMessageBroker(MessageBrokerRegistry config) {
        // Enable simple in-memory broker for public auction topics and private user queues
        config.enableSimpleBroker("/topic", "/queue");
        config.setApplicationDestinationPrefixes("/app");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        // Direct STOMP WebSocket endpoint
        registry.addEndpoint("/ws")
                .setAllowedOriginPatterns("*");

        // SockJS fallback endpoint
        registry.addEndpoint("/ws")
                .setAllowedOriginPatterns("*")
                .withSockJS();
    }

    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        registration.interceptors(new ChannelInterceptor() {
            @Override
            public Message<?> preSend(Message<?> message, MessageChannel channel) {
                StompHeaderAccessor accessor =
                        MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);

                if (accessor != null && StompCommand.CONNECT.equals(accessor.getCommand())) {
                    String authHeader = accessor.getFirstNativeHeader("Authorization");
                    String tokenHeader = accessor.getFirstNativeHeader("token");

                    String token = null;
                    if (StringUtils.hasText(authHeader) && authHeader.startsWith("Bearer ")) {
                        token = authHeader.substring(7);
                    } else if (StringUtils.hasText(authHeader)) {
                        token = authHeader;
                    } else if (StringUtils.hasText(tokenHeader)) {
                        token = tokenHeader;
                    }

                    if (StringUtils.hasText(token) && jwtTokenProvider.validateToken(token)) {
                        UUID userId = jwtTokenProvider.getUserIdFromToken(token);
                        UsernamePasswordAuthenticationToken auth =
                                new UsernamePasswordAuthenticationToken(userId, null, Collections.emptyList());
                        accessor.setUser(auth);
                        log.info("[AUCTION_WS] CONNECT authenticated user: {}", userId);
                    } else {
                        log.info("[AUCTION_WS] CONNECT anonymous/viewer session: {}", accessor.getSessionId());
                    }
                } else if (accessor != null && StompCommand.SUBSCRIBE.equals(accessor.getCommand())) {
                    String destination = accessor.getDestination();
                    log.info("[AUCTION_WS] SUBSCRIBE destination: {} session: {}",
                            destination, accessor.getSessionId());

                    // Enforce strict authorization on private user channels
                    if (destination != null && destination.startsWith("/topic/users/")) {
                        String[] parts = destination.split("/");
                        if (parts.length >= 4) {
                            String targetUserId = parts[3];
                            java.security.Principal principal = accessor.getUser();
                            if (principal == null || !targetUserId.equalsIgnoreCase(principal.getName())) {
                                log.warn("[AUCTION_WS] Blocked unauthorized subscription to {} by principal {}",
                                        destination, principal != null ? principal.getName() : "anonymous");
                                throw new org.springframework.security.access.AccessDeniedException("Unauthorized subscription to private channel");
                            }
                        }
                    } else if (destination != null && destination.startsWith("/topic/chats/")) {
                        java.security.Principal principal = accessor.getUser();
                        if (principal == null) {
                            log.warn("[AUCTION_WS] Blocked unauthenticated subscription to chat {}", destination);
                            throw new org.springframework.security.access.AccessDeniedException("Authentication required to subscribe to chat room");
                        }
                    }
                } else if (accessor != null && StompCommand.DISCONNECT.equals(accessor.getCommand())) {
                    log.info("[AUCTION_WS] DISCONNECT session: {}", accessor.getSessionId());
                }

                return message;
            }
        });
    }
}
