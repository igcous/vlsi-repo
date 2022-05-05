import random

class SPIClass(object):
	def __init__(self,
		outfile = 'C:/Users/AK124602/Documents/vlsi-repo/spic/python/in_instr.mem'
		):
		self.outfile = outfile

	def write_instr(self, fp,addr,data, size, mode,ss):
		if mode == 'single read':
			transfer = 0
		elif mode == 'single write':
			transfer = 1
		elif mode ==  'burst read':
			transfer = 2
		elif mode == 'burst write':
			transfer = 3
		else:
			raise('write or read are only valid modes of transfer')

		if size == 'byte':
			bin_str = '{0:{fill}2b}{1:{fill}2b}{2:{fill}2b}{3:{fill}32b}{4:{fill}8b}{5:{fill}24b}\n'.format(ss,transfer,0,addr,data,0, fill = '0')
		elif size == 'half word': # 16 bits, 2 bytes
			bin_str = '{0:{fill}2b}{1:{fill}2b}{2:{fill}2b}{3:{fill}32b}{4:{fill}16b}{5:{fill}16b}\n'.format(ss,transfer,1,addr,data,0, fill = '0')
		elif size == 'word':	# 32 bits, 4 bytes
			bin_str = '{0:{fill}2b}{1:{fill}2b}{2:{fill}2b}{3:{fill}32b}{4:{fill}32b}\n'.format(ss,transfer,2,addr,data, fill = '0')
		else:
			raise('byte , half word, or word are only valid transfer sizes')

		fp.write(bin_str)

	def burst_write(self,fp,start_address,num_address,size,ss,transfer):
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
			raise('byte, half word, or word are only valid transfer sizes')

		for addr in range(num_address):
			#data = random.randint(0, max_data)
			#data = 15
			data = addr
			self.write_instr(fp,addr*addr_mult+start_address,data,size,transfer,ss)

	def burst_read(self,fp,start_address,num_address,size,ss,transfer):
		if size == 'byte':
			addr_mult = 1
		elif size == 'half word':
			addr_mult = 2
		elif size == 'word':
			addr_mult = 4
		else:
			raise('byte, half word, or word are only valid transfer sizes')

		for addr in range(num_address):
			data = 0
			self.write_instr(fp,addr*addr_mult+start_address,data,size,transfer,ss)

def main():
	spi_1 = SPIClass()

	with open(spi_1.outfile, 'w') as outfile:
		slave_select = 0
		spi_1.burst_write(outfile, 0, 2, 'word', slave_select, 'single write')
		spi_1.burst_read(outfile, 0, 2, 'word', slave_select, 'single read')
		spi_1.burst_write(outfile, 0, 16, 'word', slave_select, 'burst write')

if __name__ == '__main__':
	main()