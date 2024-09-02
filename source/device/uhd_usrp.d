module device.uhd_usrp;

import std.complex;
import std.json;
import std.string;

import device;


extern(C++, "uhd_usrp_tx_burst") nothrow @nogc
{
    struct DeviceHandler
    {
        void* _payload;
    }

    DeviceHandler setupDevice(const(char)* configJSON);
    void destroyDevice(ref DeviceHandler handler);
    ulong numTxStream(DeviceHandler handler);
    void setParam(DeviceHandler handler, const(char)* key_, ulong keylen, const(char)* jsonvalue_, ulong jsonvaluelen, const(ubyte)* info, ulong infolen);
    // void setTimeNextPPS(DeviceHandler handler, long fullsecs, double fracsecs);
    // void getTimeLastPPS(DeviceHandler handler, ref long fullsecs, ref double fracsecs);
    // void setNextCommandTime(DeviceHandler handler, long fullsecs, double fracsecs);
    void beginBurstTransmit(DeviceHandler handler);
    void endBurstTransmit(DeviceHandler handler);
    ulong burstTransmit(DeviceHandler handler, const(void**) signals, ulong sample_size, ulong num_samples);
}


class UHD_USRPBurstTX : IDevice, /*IPPSSynchronizable,*/ IBurstTransmitter!(Complex!float), ILoopTransmitter!(Complex!float)
{
    import multithread : SpinLock;

    this(){}

    void construct(){}
    void destruct()
    {
        destroyDevice(this.handler);
    }


    void setup(JSONValue[string] configJSON)
    {
        this.handler = setupDevice(JSONValue(configJSON).toString().toStringz());
    }


    size_t numTxStreamImpl() shared
    {
        spinLock.lock();
        scope(exit) spinLock.unlock();        

        return .numTxStream(cast()this.handler);
    }


    size_t numRxStreamImpl() shared { return 0; }


    void setParam(const(char)[] key, const(char)[] value, scope const(ubyte)[] q) shared
    {
        .setParam(cast()this.handler, key.ptr, key.length, value.ptr, value.length, q.ptr, q.length);
    }


    const(char)[] getParam(const(char)[] key, scope const(ubyte)[] q) shared { assert(q.length == 0, "additional arguments is not supported"); assert(0, "this is not implemented."); return null; }


    void query(scope const(ubyte)[] q, scope void delegate(scope const(ubyte)[]) writer) shared
    {
        assert(0, "this is not implemented.");
    }


    // void setTimeNextPPS(DeviceTime t) shared
    // {
    //     spinLock.lock();
    //     scope(exit) spinLock.unlock();     

    //     .setTimeNextPPS(cast()this.handler, t.fullsecs, t.fracsecs);
    // }


    // DeviceTime getTimeLastPPS() shared
    // {
    //     spinLock.lock();
    //     scope(exit) spinLock.unlock();     

    //     DeviceTime t;
    //     .getTimeLastPPS(cast()this.handler, t.fullsecs, t.fracsecs);
    //     return t;
    // }


    // void setNextCommandTime(DeviceTime t) shared
    // {
    //     spinLock.lock();
    //     scope(exit) spinLock.unlock();     

    //     .setNextCommandTime(cast()this.handler, t.fullsecs, t.fracsecs);
    // }


    void beginBurstTransmit(scope const(ubyte)[] q) shared
    {
        assert(q.length == 0, "additional arguments is not supported");
        spinLock.lock();
        scope(exit) spinLock.unlock();

        .beginBurstTransmit(cast()this.handler);
    }


    void endBurstTransmit(scope const(ubyte)[] q) shared
    {
        assert(q.length == 0, "additional arguments is not supported");
        spinLock.lock();
        scope(exit) spinLock.unlock();

        .endBurstTransmit(cast()this.handler);
    }


    void burstTransmit(scope const Complex!float[][] signals, scope const(ubyte)[] q) shared
    {
        assert(q.length == 0, "additional arguments is not supported");
        const(Complex!float)*[128] _tmp;
        foreach(i; 0 .. signals.length)
            _tmp[i] = signals[i].ptr;

        size_t remain = signals[0].length;
        while(remain != 0) {
            size_t num;
            {
                spinLock.lock();
                scope(exit) spinLock.unlock();
                num = .burstTransmit(cast()this.handler, cast(const(void)**)_tmp.ptr, (Complex!float).sizeof, signals[0].length);
            }

            foreach(i; 0 .. signals.length)
                _tmp[i] += num;
            
            remain -= num;
        }
    }


    mixin LoopByBurst!(Complex!float);


  private:
    DeviceHandler handler;
    shared(SpinLock) spinLock;
}

unittest
{
    UHD_USRPBurstTX a;
}