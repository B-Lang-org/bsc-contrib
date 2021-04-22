
import "BDPI" function Bool messageAvailable();
import "BDPI" function ActionValue#(Bit#(64)) getMessage();
import "BDPI" function Action putMessage(Bit#(64) res);
