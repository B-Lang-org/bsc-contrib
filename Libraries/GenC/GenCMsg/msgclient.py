#!/usr/bin/env python3

import threading
import select
import eventfd
import time
from cobs import cobs

class Client:
    def __init__(self, name, ffi, lib, serial):
        self.name = name
        self.ffi = ffi
        self.lib = lib
        self.channelTypes = {
            fieldName[:-4]: field.type.item
            for fieldName, field in self.ffi.typeof(name + "_state").fields
            if fieldName.endswith('_buf')
        }
        self.serial = serial
        self._state = self.ffi.new(name + "_state *")
        getattr(self.lib, "init_" + name)(self._state)
        self._stateMutex = threading.Lock()
        self._txReady = eventfd.EventFD()
        self._txDone = eventfd.EventFD()

    def _run(self):
        rxData = []
        self._stateMutex.acquire()
        while True:
            for byte in self.serial.read(self.serial.in_waiting):
                if byte == 0:
                    #print("Rx raw", bytes(rxData))
                    #print("Rx", cobs.decode(bytes(rxData)))
                    getattr(self.lib, "decode_" + self.name)(self._state, cobs.decode(bytes(rxData)))
                    rxData.clear()
                else:
                    rxData.append(byte)

            txArray = self.ffi.new("uint8_t[]", getattr(self.lib, "size_tx_" + self.name))
            txSize = getattr(self.lib, "encode_" + self.name)(self._state, txArray)
            if txSize:
                while txSize:
                    txData = bytes(txArray)[0:txSize]
                    #print("Tx", txSize, txData)
                    #print("Tx raw", cobs.encode(txData) + b'\0')
                    self.serial.write(cobs.encode(txData) + b'\0')
                    self._txDone.set()
                    txSize = getattr(self.lib, "encode_" + self.name)(self._state, txArray)
            else:
                self._stateMutex.release()
                select.select([self.serial, self._txReady], [], [])
                self._stateMutex.acquire()
                self._txReady.clear()

    def start(self):
        """Start listening for and sending messages"""
        threading.Thread(target=self._run, daemon=True).start()

    def put(self, channel, data):
        """Enqueue a message into a channel, blocks until there is space available"""
        if channel not in self.channelTypes:
            raise KeyError("{} does not have message channel {}".format(self.name, channel))
        self._stateMutex.acquire()
        while not getattr(self.lib, "enqueue_{}_{}".format(self.name, channel))(self._state, data):
            self._stateMutex.release()
            self._txDone.wait()
            self._stateMutex.acquire()
            self._txDone.clear()

        self._txReady.set()
        self._stateMutex.release()

    def avail(self, channel):
        """Return the number of available messages in a channel"""
        if channel not in self.channelTypes:
            raise KeyError("{} does not have message channel {}".format(self.name, channel))
        return getattr(self._state, channel + "_size")

    def get(self, channel):
        """Dequeues a message from a channel, or returns None if no message is available"""
        if channel not in self.channelTypes:
            raise KeyError("{} does not have message channel {}".format(self.name, channel))
        res = self.ffi.new(self.channelTypes[channel].cname + " *")
        self._stateMutex.acquire()
        hasRes = getattr(self.lib, "dequeue_{}_{}".format(self.name, channel))(self._state, res)
        self._txReady.set()
        self._stateMutex.release()
        if hasRes:
            return res[0]
