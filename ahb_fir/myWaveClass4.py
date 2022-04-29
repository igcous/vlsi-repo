import numpy as np
import math as mt
import matplotlib.pyplot as plt
from scipy.signal import kaiserord, lfilter, firwin, freqz
from pylab import *
from AmbaClass3 import *

class WaveClass(object):
	def __init__(self,
				 bits,
				 amplitudes,
				 frequencies,
				 sampling_rate=44e3,

				 n_period=10,
				 infile='C:/Users/AK124602/Documents/vlsi-repo/ahb_fir/python/out_wave.mem',
				 outfile = 'C:/Users/AK124602/Documents/vlsi-repo/ahb_fir/python/in_amba_instr.mem',
				 outfile2 = 'C:/Users/AK124602/Documents/vlsi-repo/ahb_fir/python/in_coefs.mem'
				 ):

		self.bits = bits
		self.frequencies = frequencies
		self.amplitudes = amplitudes

		self.infile = infile
		self.outfile = outfile
		self.outfile2 = outfile2
		self.n_period = n_period
		self.sampling_rate = sampling_rate

	def gen_waves(self, isplot=False):
		if max(self.frequencies) * 2 >= self.sampling_rate:
			raise Exception('Nyquist ERROR.')

		end_t = self.n_period / min(self.frequencies) # endtime is the number of periods of the lowest frequency component
		n_vector = np.array(range(0, mt.ceil(end_t * self.sampling_rate)))  # number of samples

		# generate wave components
		waves = []
		for freq, ampl in zip(self.frequencies, self.amplitudes):
			wave = ampl * np.sin(2 * np.pi * freq / self.sampling_rate * n_vector)
			waves.append(wave)
		waveout = [0 for xx in n_vector]

		# add waves together
		for wave in waves:
			waveout += wave

		waveout -= min(waveout)  # Remove the min value, wave = [0 max(wave)]
		waveout = 2 * (waveout / max(waveout)) - 1 # wave = [-1 1], no offset

		if isplot:
			plt.figure()
			plt.plot(waveout)
			plt.xlabel('Samples')
			plt.ylabel('Amplitude')
			plt.title('Read Waveform')
			plt.show()

		self.wave = waveout
		return waveout, waves

	def quantize(self, isplot=False):
		wave = self.wave
		bits = self.bits

		wave = np.round(wave * (2 ** (bits-1) - 1))

		#wave = -1*np.ones(wave.size)

		if isplot:
			plt.figure()
			plt.plot(self.wave*(2 ** (bits-1) - 1))
			plt.plot(wave)
			plt.xlabel('Samples')
			plt.ylabel('Amplitude')
			plt.title('Full vs quantized Waveform')
			plt.show()

		self.qwave = wave

	def write_wave(self, bit_output=32, isplot = False):

		filepath = self.outfile
		filepath2 = self.outfile2

		wave = self.qwave
		qtaps = self.qtaps
		max_value = 2**self.bits-1

		with open(filepath, 'w') as outfile:
			for val in wave:
				if val < 0:
					bin_str = "{0:0b}".format((int(-val) ^ max_value) + 1)	# 2-complement
					bin_str = '1'*(bit_output-self.bits) + bin_str + '\n' 	# completing with ones
				else:
					bin_str = bin(np.uint(val))[2:].zfill(bit_output) + '\n'
				outfile.write(bin_str)

		with open(filepath2, 'w') as outfile:
			for val in qtaps:
				if val < 0:
					bin_str = "{0:0b}".format((int(-val) ^ max_value) + 1)	# 2-complement
					bin_str = '1'*(bit_output-self.bits) + bin_str + '\n' 	# completing with ones
				else:
					bin_str = bin(np.uint(val))[2:].zfill(bit_output) + '\n'
				outfile.write(bin_str)

		if isplot:
			plt.figure()
			plt.plot(wave)
			plt.xlabel('Samples')
			plt.ylabel('Amplitude')
			plt.title('Written Waveform')
			plt.show()

	def write_wave_as_ahb(self, start_address, size):

		# AHB config
		if size == 'byte':
			addr_mult = 1
			hsize = 0
			bit_size = 8
		elif size == 'half word':
			addr_mult = 2
			hsize = 1
			bit_size = 16
		elif size == 'word':
			addr_mult = 4
			hsize = 2
			bit_size = 32
		else:
			raise('byte , half word, or word are only valid transfer sizes')

		hwrite = 1
		htrans = 2

		# Output files
		filepath = self.outfile
		filepath2 = self.outfile2

		# Write wave to file (AHB)
		amba_1 = AmbaClass3(outfile=filepath)
		wave = self.qwave
		max_value = 2**self.bits-1
		with open(filepath, 'w') as outfile:
			# Write wave to FIR
			slave_select = 0
			addr = 0
			for val in wave:
				if val < 0:
					data = "{0:0b}".format((int(-val) ^ max_value) + 1)	# 2-complement
					data = '1'*(bit_size-self.bits) + data 	# completing with ones
				else:
					data = bin(np.uint(val))[2:].zfill(bit_size)
				bin_str = '{0:1b}{1:{fill}3b}{2:{fill}2b}{3:{fill}4b}{4:{fill}28b}{5:s}\n'.format(hwrite, hsize, htrans, slave_select, addr, data, fill='0') # instruction length = 70 bits
				outfile.write(bin_str)
				#addr = addr+addr_mult

			# Read all FIFO
			slave_select = 1
			fifo_size = 1024
			for i in range(fifo_size):
				amba_1.burst_read(outfile, 0, 1, 'word', slave_select)


		# Write coefficients to file (not AHB)
		bit_output = 32
		qtaps = self.qtaps
		max_value = 2 ** self.bits - 1
		with open(filepath2, 'w') as outfile:
			for val in qtaps:
				if val < 0:
					bin_str = "{0:0b}".format((int(-val) ^ max_value) + 1)	# 2-complement
					bin_str = '1'*(bit_output-self.bits) + bin_str + '\n' 	# completing with ones
				else:
					bin_str = bin(np.uint(val))[2:].zfill(bit_output) + '\n'
				outfile.write(bin_str)

	def read_wave(self, isplot=False):
		filepath = self.infile
		wave = []
		with open(filepath, 'r') as infile:
			for bin_str in infile:
				data = bin_str[:-1] # remove newline
				bits = 21
				data = data[32-bits:]
				aux = len(data)
				data = int(data,2)

				if data > 2**(bits-1):
					data = data-(2**bits)
				wave.append(data)

		self.rwave = wave

		read_filtered_wave = np.array(wave) * self.qtaps_scale / (2 ** (self.bits-1) - 1)
		filtered_wave = self.fqwave * self.qtaps_scale / (2 ** (self.bits-1) - 1)

		if isplot:
			plt.figure()
			plt.plot(self.qwave)
			plt.plot(filtered_wave)
			plt.plot(read_filtered_wave)
			plt.xlabel('Samples')
			plt.ylabel('Amplitude')
			plt.title('Original vs Filtered waveform vs Read waveform')
			plt.show()

			plt.figure()
			fft_db_1 = 20 * np.log10(np.abs(fft(self.qwave) / len(self.qwave)) + 0.00000001)
			fft_db_2 = 20 * np.log10(np.abs(fft(read_filtered_wave) / len(read_filtered_wave)) + 0.00000001)
			plt.plot(fft_db_1)
			plt.plot(fft_db_2)
			plt.xlabel('Samples')
			plt.ylabel('Amplitude (db)')
			plt.title('FFT - Quantized wave vs Read filtered wave')
			plt.show()


	def gen_fir_filter(self, N, cutoff_hz, ripple_db, stopband_hz):
		# This part is written according to
		# https://scipy-cookbook.readthedocs.io/items/FIRFilter.html

		if N is None:
			# Compute the order and Kaiser parameter for the FIR filter.
			N, beta = kaiserord(ripple_db, stopband_hz/(self.sampling_rate/2.0))

			# Use firwin with a Kaiser window to create a lowpass FIR filter.
			#win = firwin(N, cutoff_hz / (self.sampling_rate/2.0), window=('kaiser', beta), fs=self.sampling_rate)
			taps = firwin(N, cutoff_hz, window=('kaiser', beta), fs=self.sampling_rate)
		else:
			taps = firwin(N, cutoff_hz, fs=self.sampling_rate, pass_zero = 'lowpass')


		self.taps = taps

		qtaps = taps / max(np.abs(taps))
		qtaps = qtaps * (2 ** (self.bits-1) - 1)
		qtaps = np.round(qtaps)

		# # Testing qtaps
		# qtaps = np.append(np.ones([1]),np.zeros([N-1]),axis=0) # impulse, no filter
		# qtaps = -1*np.ones([N]) # max filter
		# qtaps=qtaps.tolist()


		self.qtaps = qtaps

		self.qtaps_scale = max(np.abs(taps))

	def fir_filter(self, isplot=False):

		# Full
		taps = self.taps
		wave = self.wave
		# Use lfilter to filter x with the FIR filter.
		filtered_wave = lfilter(taps, 1.0, wave)

		# Scale factors to compare with quantized wave
		wave = wave * (2 ** (self.bits-1) - 1)
		filtered_wave = filtered_wave * (2 ** (self.bits-1) - 1)

		self.fwave = filtered_wave

		if isplot:
			plt.figure()
			# Plot the original signal
			plt.plot(wave)
			# Plot the filtered signal, shifted to compensate for the phase delay

			# The phase delay of the filtered signal.
			delay = round(0.5 * (len(taps) - 1))

			plt.plot(filtered_wave[delay:])
			#plt.plot(filtered_wave)
			plt.xlabel('Samples')
			plt.ylabel('Amplitude')
			plt.title('Full vs filtered Waveform - Not Quantized')
			plt.show()

			plt.figure()
			fft_db_1 = 20 * np.log10(np.abs(fft(wave) / len(wave)) + 0.00000001)
			fft_db_2 = 20 * np.log10(np.abs(fft(filtered_wave) / len(filtered_wave)) + 0.00000001)
			plt.plot(fft_db_1)
			plt.plot(fft_db_2)
			plt.xlabel('Samples')
			plt.ylabel('Amplitude (db)')
			plt.title('FFT - Not Quantized')
			plt.show()


		# Quantized
		taps = self.qtaps
		wave = self.qwave
		# Use lfilter to filter x with the FIR filter.
		filtered_wave = lfilter(taps, 1.0, wave)

		self.fqwave = filtered_wave
		filtered_wave = filtered_wave * self.qtaps_scale / (2 ** (self.bits-1) - 1) # factor for plotting against original

		if isplot:
			plt.figure()
			# Plot the original signal
			plt.plot(wave)
			# Plot the filtered signal, shifted to compensate for the phase delay

			# The phase delay of the filtered signal.
			delay = round(0.5 * (len(taps) - 1))

			plt.plot(filtered_wave[delay:])
			#plt.plot(filtered_wave)
			plt.xlabel('Samples')
			plt.ylabel('Amplitude')
			plt.title('Full vs filtered Waveform - Quantized')
			plt.show()

			plt.figure()
			fft_db_1 = 20 * np.log10(np.abs(fft(wave) / len(wave)) + 0.00000001)
			fft_db_2 = 20 * np.log10(np.abs(fft(filtered_wave) / len(filtered_wave)) + 0.00000001)
			plt.plot(fft_db_1)
			plt.plot(fft_db_2)
			plt.xlabel('Samples')
			plt.ylabel('Amplitude (db)')
			plt.title('FFT - Quantized')
			plt.show()


	def mfreqz(self): # Compute the frequency response of a digital filter
		b = self.taps * (2 ** (self.bits-1) - 1) / self.qtaps_scale
		a = 1
		w, h = freqz(b, a)
		h_dB = 20 * log10(abs(h))
		h_Phase = unwrap(arctan2(imag(h), real(h)))

		b = self.qtaps
		a = 1
		w, h = freqz(b, a)
		h_dB_q = 20 * log10(abs(h))
		h_Phase_q = unwrap(arctan2(imag(h), real(h)))

		plt.figure()
		plt.plot(w / max(w), h_dB)
		plt.plot(w / max(w), h_dB_q)
		plt.ylabel('Magnitude (db)')
		plt.xlabel('Normalized Frequency (pi rad/sample)')
		plt.title('Frequency response')
		plt.show()

		plt.figure()
		plt.plot(w / max(w), h_Phase)
		plt.plot(w / max(w), h_Phase_q)
		plt.ylabel('Phase (radians)')
		plt.xlabel('Normalized Frequency (pi rad/sample)')
		plt.title('Phase response')
		plt.show()


	def impz(self): # Plot step and impulse response
		b = self.taps * (2 ** (self.bits-1) - 1) / self.qtaps_scale
		a = 1
		l = len(b)
		impulse = repeat(0., l)
		impulse[0] = 1.
		x = arange(0, l)
		response = lfilter(b, a, impulse)
		step = cumsum(response)

		b = self.qtaps
		a = 1
		l = len(b)
		impulse = repeat(0., l)
		impulse[0] = 1.
		x = arange(0, l)
		response_q = lfilter(b, a, impulse)
		#response_q = response_q * self.qtaps_scale / (2 ** (self.bits - 1) - 1)
		step_q = cumsum(response_q)

		plt.figure()
		plt.plot(response)
		plt.plot(response_q)
		plt.ylabel('Amplitude')
		plt.xlabel('n (samples)')
		plt.title('Impulse response')
		plt.show()

		plt.figure()
		plt.plot(step)
		plt.plot(step_q)
		plt.ylabel('Amplitude')
		plt.xlabel('n (samples)')
		plt.title('Step response')
		plt.show()

def main():

	# ######################################################
	# # Example 1: Wave generation
	# ######################################################
	#
	# plot_flg = False
	# waves1 = WaveClass(bits = 4, frequencies = [100, 500, 3000], amplitudes = [1,1,1])
	# waves1.gen_waves(isplot = plot_flg)
	# waves1.quantize(isplot = plot_flg)
	# waves1.write_wave()
	# waves1.read_wave(isplot = plot_flg)

	######################################################
	# FIR filter generation
	######################################################

	# FIR filter parameters
	N = 20 # Fixed number of taps
	cutoff_hz = 10000 # The cutoff frequency of the filter
	ripple_db = 60.0 # The desired attenuation in the stop band, in dB.
	stopband_hz = 500 # The desired width of the transition from pass to stop

	plot_flg = False
	waves2 = WaveClass(bits=8, frequencies=[500, 1000, 20000], amplitudes=[1.0,1.0,1.0])
	waves2.gen_waves(isplot=plot_flg)
	waves2.quantize(isplot=plot_flg)
	waves2.gen_fir_filter(N = N, cutoff_hz = cutoff_hz, ripple_db = ripple_db, stopband_hz = stopband_hz)
	waves2.fir_filter(isplot=plot_flg)
	print("Number of taps ", len(waves2.taps))
	#waves2.mfreqz()
	#waves2.impz()

	#waves2.write_wave(isplot = plot_flg)
	#waves2.write_wave_as_ahb(0,'word')

	waves2.read_wave(isplot = True)

if __name__ == '__main__':
	main()