class ahb_txn extends uvm_sequence_item;
 
 
    rand bit [31:0] addr;         // start address (beat 0)
    rand bit  write;
    rand bit [2:0] size;        // HSIZE: 0=byte,1=hword,2=word
     bit [3:0] prot;
    rand ahb_burst_e  burst;
    rand int unsigned incr_len;    // only meaningful when burst==AHB_INCR
 
    rand bit [31:0]     data[];      // write data, one entry per beat
         bit [31:0]     rd_data[];   // read data,  filled in by the driver
         bit            error_resp;  // set if ANY beat returned HRESP=ERROR 
    `uvm_object_utils_begin(ahb_txn)
      `uvm_field_int      (addr,       UVM_HEX)
      `uvm_field_int      (write,      UVM_BIN)
      `uvm_field_int      (size,       UVM_HEX)
      `uvm_field_enum     (ahb_burst_e, burst, UVM_HEX)
      `uvm_field_int      (incr_len,   UVM_DEC)
      `uvm_field_array_int(data,       UVM_HEX)
      `uvm_field_array_int(rd_data,    UVM_HEX)
      `uvm_field_int      (error_resp, UVM_BIN)
    `uvm_object_utils_end
    constraint c_size     { size inside {0, 1, 2}; }
    constraint c_incr_len { incr_len inside {[1:32]}; }
    constraint c_beats {
      (burst == AHB_SINGLE)  -> data.size() == 1;
      (burst inside {AHB_WRAP4,  AHB_INCR4})  -> data.size() == 4;
      (burst inside {AHB_WRAP8,  AHB_INCR8})  -> data.size() == 8;
      (burst inside {AHB_WRAP16, AHB_INCR16}) -> data.size() == 16;
      (burst == AHB_INCR) -> data.size() == incr_len;
    }
 
    // Address alignment to HSIZE
    constraint c_align {
      (size == 1) -> addr[0]   == 1'b0;
      (size == 2) -> addr[1:0] == 2'b00;
    }
 
    function new(string name = "ahb_txn");
      super.new(name);
    endfunction
 
    function int num_beats();
      return data.size();
    endfunction
 
  endclass
 
