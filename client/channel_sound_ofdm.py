import multiusrp
import numpy as np
import time
import matplotlib.pyplot as plt
from matplotlib import animation

# サーバーIPとポート番号
IPADDR = "127.0.0.1";
PORT = 8888;

nTXUSRP = 2     # 送信機2台
nRXUSRP = 2     # 受信機2台

bpsk_constellation = np.array([1+0j, -1+0j])
qpsk_constellation = np.array([1+1j, -1+1j, -1-1j, 1-1j]) / np.sqrt(2)

nOS = 2                 # OFDMのオーバーサンプリング率
nSC = 256               # OFDMの有効サブキャリア数
nFFT = nSC * nOS        # OFDM変調のFFTサイズ
nCP = nFFT//4           # CPのサイズ


# OFDM変調
def mod_ofdm(scs):
    nSYM = len(scs)//nSC
    scs = scs.reshape([nSYM, nSC])
    scs = np.hstack((np.zeros((nSYM,1)), scs[:,:nSC//2], np.zeros((nSYM, nFFT - nSC - 1)), scs[:,nSC//2:]))
    sym = np.fft.ifft(scs, norm="ortho")        # IFFT
    sym = np.hstack((sym[:,nFFT-nCP:], sym))    # add CP
    return sym.reshape((nFFT+nCP)*nSYM)


# OFDM復調
def demod_ofdm(sym):
    nSYM = len(sym)//(nFFT + nCP)
    sym = sym.reshape([nSYM, nFFT + nCP])
    sym = sym[:,nCP:]                           # remove CP
    scs = np.fft.fft(sym, norm="ortho")         # FFT
    scs = np.hstack((scs[:,1:nSC//2+1], scs[:,nFFT-nSC//2:]))
    return scs.reshape(nSYM * nSC)


with multiusrp.SimpleClient(IPADDR, PORT, nTXUSRP, nRXUSRP) as usrp:

    # 1回の送受信で100シンボル伝送する
    nTxSYM = 100

    # BPSK,QPSK変調したサブキャリア
    subcarriers = [
        np.random.choice(bpsk_constellation, nSC*nTxSYM),
        np.random.choice(qpsk_constellation, nSC*nTxSYM),
    ]

    # OFDM変調した信号
    modulated = [
        mod_ofdm(subcarriers[0]),
        mod_ofdm(subcarriers[1]),
    ]

    fig = plt.figure()
    ax1 = fig.add_subplot(1, 2, 1)
    ax2 = fig.add_subplot(1, 2, 2)

    usrp.changeRxAlignSize(len(modulated[0]))   # USRPの受信バッファのサイズを信号長に合わせる
    usrp.transmit(modulated)                    # 送信信号を設定する
    usrp.sync()                                 # 送受信機で同期を取る

    def estimateChannel():
        # チャネル推定用に受信
        recv = usrp.receive(len(modulated[0]))
        demodulated = [
            demod_ofdm(recv[0]),
            demod_ofdm(recv[1]),
        ]

        # チャネル推定
        channel_resp = [
            np.mean((demodulated[0] / subcarriers[0]).reshape([nTxSYM, nSC]), axis=0),
            np.mean((demodulated[1] / subcarriers[1]).reshape([nTxSYM, nSC]), axis=0),
        ]

        return channel_resp


    def plot(data):
        # global frame_count
        # global starttime
        # global recv100
        # global mean_psd

        estCh = estimateChannel()

        # plt.cla()
        ax1.clear()
        ax2.clear()

        ax1.plot(np.linspace(0, nSC-1, nSC), np.abs(estCh[0]))
        ax1.plot(np.linspace(0, nSC-1, nSC), np.abs(estCh[1]))

        ax2.plot(np.linspace(0, nSC-1, nSC), np.arg(estCh[0]))
        ax2.plot(np.linspace(0, nSC-1, nSC), np.arg(estCh[1]))

        ax1.set_xlim([0, nSC-1])
        ax2.set_xlim([0, nSC-1])

        # ax1.plot(np.real(recv), np.imag(recv))
        # ax2.plot(np.linspace(-0.5, 0.5, nSamples), 10 * np.log10(mean_psd))
        # ax2.set_ylim([-70, 0])

        # frame_count += 1
    
    ani = animation.FuncAnimation(fig, plot, interval=50, blit=False)
    plt.show()