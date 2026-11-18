package com.py.brokers.angel.exception;

public class SmartAPIException extends Throwable {

	private static final long serialVersionUID = 1L;
	// variables
	public String message;
	public String code;

	// constructor that sets the message and code
	public SmartAPIException(String message, String code) {
		super(message);
		this.message = message;
		this.code = code;
	}

	// constructor that sets the message
	public SmartAPIException(String message) {
		super(message);
		this.message = message;
	}

	@Override
	public String toString() {
		return "SmartAPIException [message=" + message + ", code=" + code + "]";
	}

}


