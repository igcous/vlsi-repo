import random

"""
AmbaClass Class
Member functions:
write_amba_instr:
	takes data arguments, converts to binary word
burst_write:
	takes start address and number of addresses and hsize, writes randomly selected data based on hsize to stimulus file, saves data and address for debugging
burst_read:
	takes start address and number of addresses and hsize, reads from consecutive locations in memory based on hsize 
"""

class AmbaClass3(object):
	def __init__(self,
		outfile = 'C:/Users/AK124602/Documents/vlsi-repo/fifo_fir_v1/python/in_instr.mem'
		#outfile = './vhdl/in.mem'
		):
		self.addr_width = 32
		self.data_width = 32
		self.outfile = outfile

	def write_amba_instr(self, fp,addr,data, size, mode,slave):
		if mode == 'write':
			hwrite = 1
		elif mode == 'read':
			hwrite = 0
		else:
			raise('write or read are only valid modes of transfer')

		htrans = 2

		if size == 'byte':
			hsize = 0
		elif size == 'half word': # 16 bits, 2 bytes
			hsize = 1
		elif size == 'word':	# 32 bits, 4 bytes
			hsize = 2
		else:
			raise('byte , half word, or word are only valid transfer sizes')

		bin_str = '{0:1b}{1:{fill}3b}{2:{fill}2b}{3:{fill}4b}{4:{fill}28b}{5:{fill}32b}\n'.format(hwrite,hsize,htrans,slave,addr,data, fill = '0')
		fp.write(bin_str)

	def burst_write(self,fp,start_address,num_address,size,slave):
		if size == 'byte':
			max_data = 2**8-1
			addr_mult = 1
		elif size == 'half word':
			max_data = 2**16-1
			addr_mult = 2
		elif size == 'word':
			max_data = 2**32-1
			addr_mult = 4
		else:
			raise('byte , half word, or word are only valid transfer sizes')

		data = 0
		for addr in range(num_address):
			#data = random.randint(0, max_data)
			#data = 85
			#data = addr
			self.write_amba_instr(fp,addr*addr_mult+start_address,data,size,'write',slave)
			data = data + 1

	def burst_read(self,fp,start_address,num_address,size,slave):
		if size == 'byte':
			addr_mult = 1
		elif size == 'half word':
			addr_mult = 2
		elif size == 'word':
			addr_mult = 4
		else:
			raise('byte , half word, or word are only valid transfer sizes')

		for addr in range(num_address):
			data = 0
			self.write_amba_instr(fp,addr*addr_mult+start_address,data,size,'read',slave)


def main():
	amba_1 = AmbaClass()

	"""
	~~test procedure~~
	demo class functionality, write to test.mem
	1. write to 10 addresses of size word starting at address 0
	2. read from 20 address of size half word starting at address 0
	"""

	print("Write dummy data to ./in.mem")
	slave_select = 1
	with open(amba_1.outfile, 'w') as outfile:
		#amba_1.burst_write(outfile,0,2,'byte',slave_select)
		amba_1.burst_read(outfile,0,1024,'word',slave_select)

if __name__ == '__main__':
	main()