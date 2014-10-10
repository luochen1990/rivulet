// Generated by CoffeeScript 1.7.1
(function() {
  var Behavior, EventStream, Signal, extractB, extractE, mapB, timerE,
    __slice = [].slice;

  Signal = (function() {
    var emitter, events, gensym;
    gensym = (function() {
      var cnt;
      cnt = 0;
      return function() {
        cnt += 1;
        return "rivulet#" + cnt;
      };
    })();
    if (typeof window !== "undefined" && window !== null) {
      Signal = (function() {
        function Signal() {
          this._symbol = gensym();
        }

        Signal.prototype.name = function() {
          return this._symbol;
        };

        Signal.prototype.trigger = function(e) {
          return $(document).trigger(this._symbol, e);
        };

        Signal.prototype.register = function(handler) {
          var f;
          f = function(_, e) {
            return handler(e);
          };
          $(document).on(this._symbol, f);
          return (function(_this) {
            return function() {
              return $(document).unbind(_this._symbol, f);
            };
          })(this);
        };

        Signal.prototype.cancel = function() {
          return $(document).unbind(this._symbol);
        };

        return Signal;

      })();
    } else {
      events = require('events');
      emitter = new events.EventEmitter;
      emitter.setMaxListeners(0);
      Signal = (function() {
        function Signal() {
          this._symbol = gensym();
        }

        Signal.prototype.name = function() {
          return this._symbol;
        };

        Signal.prototype.trigger = function(e) {
          return emitter.emit(this._symbol, e);
        };

        Signal.prototype.register = function(f) {
          emitter.on(this._symbol, f);
          return (function(_this) {
            return function() {
              return emitter.removeListener(_this._symbol, f);
            };
          })(this);
        };

        Signal.prototype.cancel = function() {
          return emitter.removeAllListeners(this._symbol);
        };

        return Signal;

      })();
    }
    return Signal;
  })();

  EventStream = (function() {
    function EventStream(signal) {
      this.signal = signal != null ? signal : new Signal;
    }

    EventStream.prototype.push = function(e) {
      return this.signal.trigger(e);
    };

    EventStream.prototype["do"] = function(foo) {
      return this.signal.register(foo);
    };

    EventStream.prototype.close = function() {
      return this.signal.cancel();
    };

    EventStream.prototype.once = function(foo) {
      return this.signal.register(((function(_this) {
        return function() {
          foo();
          return _this.signal.cancel();
        };
      })(this)));
    };

    return EventStream;

  })();

  Behavior = (function() {
    function Behavior(_value, _equal) {
      this._value = _value;
      this._equal = _equal != null ? _equal : (function(a, b) {
        return a === b && !(a instanceof Object) && !(b instanceof Object);
      });
      this.changeE = new EventStream;
    }

    Behavior.prototype.value = function() {
      return this._value;
    };

    Behavior.prototype.update = function(es, f) {
      if (f == null) {
        f = (function(e) {
          return e;
        });
      }
      return es["do"]((function(_this) {
        return function(e) {
          var new_value;
          new_value = f(e, _this._value);
          if (!_this._equal(new_value, _this._value)) {
            _this.changeE.push([new_value, _this._value]);
            return _this._value = new_value;
          }
        };
      })(this));
    };

    Behavior.prototype.apply = function(use) {
      use(this._value);
      return this.changeE["do"](function(v) {
        return use(v);
      });
    };

    return Behavior;

  })();

  extractE = function(elem_selector, event_name) {
    var event_stream;
    event_stream = new EventStream;
    $(elem_selector).on(event_name, function(e) {
      return setTimeout(function() {
        return event_stream.push(e);
      });
    });
    return event_stream;
  };

  timerE = function(interval) {
    var alarm, event_stream, time;
    event_stream = new EventStream;
    time = 0;
    alarm = function() {
      event_stream.push(time);
      time += 1;
      return setTimeout(alarm, interval * 1000);
    };
    alarm();
    return event_stream;
  };

  extractB = function(interval, get_value, equal) {
    var behav;
    behav = new Behavior(get_value(), equal);
    return behav.update(timerE(interval), function(e) {
      return get_value();
    });
  };

  EventStream.prototype.transferE = function(transfer) {
    var callback, event_stream;
    event_stream = new EventStream;
    callback = transfer(event_stream);
    this["do"](function(e) {
      return callback(e);
    });
    return event_stream;
  };

  EventStream.mergeE = function() {
    var es, es_ls, event_stream, _i, _len;
    es_ls = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    event_stream = new EventStream;
    for (_i = 0, _len = es_ls.length; _i < _len; _i++) {
      es = es_ls[_i];
      es["do"](function(e) {
        return event_stream.push(e);
      });
    }
    return event_stream;
  };

  EventStream.zipE = function() {
    var es_ls;
    es_ls = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    es_ls.forEach(function(es, k) {
      return es_ls[k] = es.mapE(function(e) {
        return [k, e];
      });
    });
    return EventStream.mergeE.apply(EventStream, es_ls).transferE(function(res) {
      var buffers, es, k, pending_count;
      buffers = dict((function() {
        var _i, _len, _results;
        _results = [];
        for (k = _i = 0, _len = es_ls.length; _i < _len; k = ++_i) {
          es = es_ls[k];
          _results.push([k, []]);
        }
        return _results;
      })());
      pending_count = es_ls.length;
      return function(_arg) {
        var e, k, v, _results;
        k = _arg[0], e = _arg[1];
        buffers[k].push(e);
        if (buffers[k].length === 1) {
          pending_count -= 1;
        }
        if (pending_count === 0) {
          res.push((function() {
            var _results;
            _results = [];
            for (k in buffers) {
              v = buffers[k];
              _results.push(v[0]);
            }
            return _results;
          })());
          for (k in buffers) {
            v = buffers[k];
            v.splice(0, 1);
          }
          _results = [];
          for (k in buffers) {
            v = buffers[k];
            if (v.length === 0) {
              _results.push(pending_count += 1);
            }
          }
          return _results;
        }
      };
    });
  };

  EventStream.prototype.mapE = function(f) {
    var event_stream;
    if (f == null) {
      f = (function(e) {
        return e;
      });
    }
    event_stream = new EventStream;
    this["do"](function(e) {
      return event_stream.push(f(e));
    });
    return event_stream;
  };

  EventStream.prototype.filterE = function(ok) {
    var event_stream;
    event_stream = new EventStream;
    this["do"](function(e) {
      if (ok(e)) {
        return event_stream.push(e);
      }
    });
    return event_stream;
  };

  EventStream.prototype.blinkE = function(n, k) {
    var cnt, event_stream, unregister;
    if (k == null) {
      k = 1;
    }
    event_stream = new EventStream;
    cnt = -n + (k < 0);
    unregister = this["do"]((function(_this) {
      return function(e) {
        if (cnt * k >= 0 && cnt % k === 0) {
          event_stream.push(e);
        } else {
          if (k < 0) {
            unregister();
            event_stream.close();
          }
        }
        return cnt += 1;
      };
    })(this));
    return event_stream;
  };

  EventStream.prototype.onceE = function() {
    return this.blinkE(1, -1);
  };

  EventStream.prototype.untilE = function(end) {
    var event_stream, unregister;
    event_stream = new EventStream;
    unregister = this["do"]((function(_this) {
      return function(e) {
        if (end(e)) {
          unregister();
          return event_stream.close();
        } else {
          return event_stream.push(e);
        }
      };
    })(this));
    return event_stream;
  };

  EventStream.prototype.delayE = function(delay) {
    var event_stream;
    event_stream = new EventStream;
    this["do"](function(e) {
      return setTimeout((function() {
        return event_stream.push(e);
      }), delay * 1000);
    });
    return event_stream;
  };

  EventStream.prototype.throttleE = function(interval) {
    var event_stream, opened;
    event_stream = new EventStream;
    opened = true;
    this["do"](function(e) {
      if (opened) {
        event_stream.push(e);
        opened = false;
        return setTimeout((function() {
          return opened = true;
        }), interval * 1000);
      }
    });
    return event_stream;
  };

  mapB = function() {
    var behav, behav_ls, behavior, equal, f, get_value, _i, _j, _len, _ref;
    f = arguments[0], behav_ls = 3 <= arguments.length ? __slice.call(arguments, 1, _i = arguments.length - 1) : (_i = 1, []), equal = arguments[_i++];
    if (equal instanceof Behavior) {
      _ref = [behav_ls.concat(equal, null)], behav_ls = _ref[0], equal = _ref[1];
    }
    get_value = function() {
      var behav;
      return f.apply(null, (function() {
        var _j, _len, _results;
        _results = [];
        for (_j = 0, _len = behav_ls.length; _j < _len; _j++) {
          behav = behav_ls[_j];
          _results.push(behav.value());
        }
        return _results;
      })());
    };
    behavior = new Behavior(get_value(), equal);
    for (_j = 0, _len = behav_ls.length; _j < _len; _j++) {
      behav = behav_ls[_j];
      behavior.update(behav.changeE(), get_value);
    }
    return behavior;
  };

  if (typeof window === "undefined" || window === null) {
    require('coffee-mate/global');
    (function() {
      var es, es1, es2;
      es1 = timerE(1);
      es2 = timerE(2);
      es = EventStream.zipE(es1, es2);
      return es["do"](function(e) {
        return log(e);
      });
    })();
  } else {
    $(document).ready(function() {
      var bh1, es1, es2, es3, es3_, es4, es5;
      log('BEGIN');
      es1 = extractE('#btn_a', 'click').mapE(function(it) {
        return it.target;
      });
      es2 = extractE('#btn_b', 'click').mapE(function(it) {
        return it.target;
      });
      es3 = timerE(1);
      es3_ = es3.transferE(function(es) {
        var cnt;
        cnt = 0;
        return function(e) {
          cnt += e;
          return es.push(cnt);
        };
      });
      es3_["do"](function(sum) {
        return log(function() {
          return sum;
        });
      });
      EventStream.mergeE(es1, es2, es3).blinkE(5, -1)["do"](function(e) {
        return log(e);
      });
      es1["do"](function(e) {
        return log(function() {
          return e;
        });
      });
      es4 = extractE('#ipt_a', 'keydown');
      es5 = extractE('#ipt_b', 'keydown');
      EventStream.mergeE(es4, es5)["do"](function(e) {
        return log(function() {
          return e;
        });
      });
      bh1 = new Behavior('hello');
      bh1.update(EventStream.mergeE(es4, es5), function(e, v) {
        return float($('#ipt_a').val()) + float($('#ipt_b').val());
      });
      log($('#lab_a'));
      log($('#lab_a').text);
      bh1.apply(function(v) {
        log($('#lab_a'));
        return $('#lab_a').text(v);
      });
      return bh1.apply(function(v) {
        return $('#ipt_c').val(v);
      });
    });
  }

}).call(this);

//# sourceMappingURL=rivulet.map
