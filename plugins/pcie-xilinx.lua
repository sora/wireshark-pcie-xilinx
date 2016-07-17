local pcie_proto = Proto("PCIe_Xilinx", "PCI Express Transport Layer Packet (Xilinx vender format)")

local f = pcie_proto.fields

-- PCIe TLP capture header: Byte 6
--  2               1             0B
-- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
-- |DIR|        Reserved           |
-- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-|
-- |            Sequence           |
-- |                               |
-- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
-- Direction, 2bit
-- Reserved, 14bit
-- Sequence, 32bit
--
local TCAPPacketDirection = {
	[0] = "CQ: Completer reQuest (RX_ENGINE)",
	[1] = "CC: Completer Completion (TX_ENGINE)",
	[2] = "RQ: Requester reQuest (TX_ENGINE)",
	[3] = "RC: Requester Completion (RX_ENGINE)",
}
f.tcap_dir  = ProtoField.uint8("pcie.tcap.direction", "Packet Direction", base.BYTES, TCAPPacketDirection)
-- f.tcap_rsvd = ProtoField.new("Reserved", "pcie.tcap.reserved", ftypes.BYTES)
f.tcap_sec  = ProtoField.new("packet sequence", "pcie.tcap.sequence", ftypes.UINT32, nil, base.HEX)

--
-- From Xilinx PG023
--
-- CQ: Completer Request Descriptor Format for Memory, I/O, and Atomic Op Requests
-- |       0       |       1       |       2       |       3       |
-- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
-- |                       Address [63:32]                         | DW+1
-- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
-- |                       Address [31:2]                      |AT | DW+0
-- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
-- |R|Attr | TC  |BARAperture|BARID|Target Function|      Tag      | DW+3
-- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
-- |          Requester ID         |R|ReqType|     Dword count     | DW+2
-- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
-- R: Reserved
-- AT: Address Type
--
f.cq_addr  = ProtoField.new("Address", "pcie.cq.addr", ftypes.UINT64, nil, base.HEX)
f.cq_at    = ProtoField.new("Address Type", "pcie.cq.at", ftypes.UINT8, nil, base.HEX)
f.cq_rsvd0 = ProtoField.new("Reserved 0", "pcie.cq.rsvd0", ftypes.UINT8, nil, base.NONE)
f.cq_attr  = ProtoField.new("Attributes", "pcie.cq.attr", ftypes.UINT8, nil, base.HEX)
f.cq_tc    = ProtoField.new("Transaction Class (TC)", "pcie.cq.tc", ftypes.UINT8, nil, base.HEX)
f.cq_barap = ProtoField.new("BAR Aperture", "pcie.cq.barap", ftypes.UINT8, nil, base.HEX)

local CQ_BARID = {
	[0] = "BAR 0 (VF-BAR 0 for VFs",
	[1] = "BAR 1 (VF-BAR 1 for VFs",
	[2] = "BAR 2 (VF-BAR 2 for VFs",
	[3] = "BAR 3 (VF-BAR 3 for VFs",
	[4] = "BAR 4 (VF-BAR 4 for VFs",
	[5] = "BAR 5 (VF-BAR 5 for VFs",
	[6] = "Expansion ROM Access",
	[7] = "No BAR Check (Valid for Root Port only)",
}
f.cq_barid = ProtoField.uint8("pcie.cq.barid", "BAR ID", base.BYTES, CQ_BARID)

local CQ_TargetFunction = {
	[ 0] = "PF0",
	[ 1] = "PF1",
	[64] = "VF0",
	[65] = "VF1",
	[66] = "VF2",
	[67] = "VF3",
	[68] = "VF4",
	[69] = "VF5",
}
f.cq_tf    = ProtoField.uint8("pcie.cq.tf", "Target Function", base.DEC, CQ_TargetFunction)
f.cq_tag   = ProtoField.new("Tag", "pcie.cq.tag", ftypes.UINT8, nil, base.HEX)
f.cq_reqid = ProtoField.new("Requester ID", "pcie.cq.reqid", ftypes.UINT16, nil, base.HEX)
f.cq_rsvd1 = ProtoField.new("Reserved 1", "pcie.cq.rsvd1", ftypes.UINT8, nil, base.NONE)

local CQ_RequestType = {
	[0] = "Memory Read Request",
	[1] = "Memory Write Request",
	[2] = "I/O Read Request",
	[3] = "I/O Write Request",
	[4] = "Memory Fetch and Add Request",
	[5] = "Memory Unconditional Swap Request",
	[6] = "Memory Compare and Swap Request",
	[7] = "Locked Read Request (allowed only in Legacy Devices)",
	[8] = "Type 0 Configuration Read Request (on Requester side only)",
}
f.cq_reqtype = ProtoField.uint8("pcie.cq.reqtype", "Request Type", base.BYTES, CQ_RequestType)
f.cq_dwlen   = ProtoField.new("Dword Count", "pcie.cq.dwlen", ftypes.UINT16, nil, base.DEC)
f.cq_data    = ProtoField.new("Data", "pcie.cq.data", ftypes.UINT64, nil, base.HEX)

function pcie_proto.dissector(buffer, pinfo, tree)
	pinfo.cols.protocol = "PCIe TLP (Xilinx)"
	local subtree = tree:add(pcie_proto, buffer(0, buffer:len()))

	local tcap_subtree = subtree:add(buffer(0,6), "TLP Capture Header")
	tcap_subtree:add(f.tcap_dir,  buffer(0,1), buffer(0,1):bitfield(0,2))
--	tcap_subtree:add(f.tcap_rsvd, buffer(0,2), buffer(0,2):bitfield(2,14))
	tcap_subtree:add(f.tcap_sec,  buffer(2,4))

	local cq_subtree = subtree:add(buffer(6, buffer:len()-6), "Transaction Layer Packet (CQ)")
	cq_subtree:add(f.cq_addr,    buffer( 6,8))
	cq_subtree:add(f.cq_at,      buffer(13,1), buffer(13,1):bitfield(6, 2))
--	cq_subtree:add(f.cq_rsvd0,   buffer(14,1), buffer(14,1):bitfield(0, 1))
	cq_subtree:add(f.cq_attr,    buffer(14,1), buffer(14,1):bitfield(1, 3))
	cq_subtree:add(f.cq_tc,      buffer(14,1), buffer(14,1):bitfield(4, 3))
	cq_subtree:add(f.cq_barap,   buffer(14,2), buffer(14,2):bitfield(7, 6))
	cq_subtree:add(f.cq_barid,   buffer(15,1), buffer(15,1):bitfield(5, 3))
	cq_subtree:add(f.cq_tf,      buffer(16,1))
	cq_subtree:add(f.cq_tag,     buffer(17,1))
	cq_subtree:add(f.cq_reqid,   buffer(18,2))
--	cq_subtree:add(f.cq_rsvd1,   buffer(20,1), buffer(20,1):bitfield(0, 1))
	cq_subtree:add(f.cq_reqtype, buffer(20,1), buffer(20,1):bitfield(1, 4))
	cq_subtree:add(f.cq_dwlen,   buffer(20,2), buffer(20,2):bitfield(5,11))

	local cqdata_subtree = subtree:add(buffer(22, buffer:len()-22), "TLP data")
	cqdata_subtree:add(f.cq_data, buffer(22,buffer:len()-22))
end

-- CC: Completer Completion Descriptor Format
-- |       0       |       1       |       2       |       3       |
-- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
-- |          Requester ID         |R|P| CS  |     Dword count     |
-- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
-- | R |L|      Byte Count         | Reserved  |AT |R|Address[6:0] |
-- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
-- |F|Attr | TC  |C|          Completer ID         |      Tag      |
-- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
-- F: Force ECRC
-- C: Completer ID Enable
-- R: Reserved
-- P: Poisoned Completion
-- CS: Completion Status
-- L: Locked Read Completion

-- RQ: Requester Request Descriptor Format for Memory, I/O, and Atomic Op Requests
-- |       0       |       1       |       2       |       3       |
-- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
-- |                       Address [63:32]                         |
-- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
-- |                       Address [31:2]                      |AT |
-- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
-- |F|Attr | TC  |E|          Completer ID         |      Tag      |
-- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
-- |          Requester ID         |P|ReqType|     Dword count     |
-- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
-- F: Force ECRC
-- E: Requester ID Enable
-- P: Poisoned Request
-- AT: Address Type

-- RC: Requester Completion Descriptor Format
-- |       0       |       1       |       2       |       3       |
-- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
-- |          Requester ID         |R|P| CS  |     Dword count     |
-- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
-- |R|Q|L|      Byte Count         | Reservd |    Address[11:0]    |
-- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
-- |R|Attr | TC  |R|          Completer ID         |      Tag      |
-- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
-- R: Reserved
-- P: Poisoned Completion
-- CS: Completion Status
-- Q: Request Completed
-- L: Locked Read Completion

-- Requester ID and Completer ID
-- |       0       |       1       |
-- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
-- |Device/Function|      Tag      |
-- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

DissectorTable.get("udp.port"):add(14198, pcie_proto)

