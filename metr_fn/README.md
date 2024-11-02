# metr_fn
Dynamic Dispatch Interfaces using a dispatch table. Function binding happens at comptime.
Supports Zig 0.12.0 to 0.13.0

## Sample
### Definition
```Zig
const ITestStruct = struct {
    const ThisType = @This();
    const FunctionTable = struct {
        static_func_fn: *const fn () u8,
        func_one_fn: *const fn (InterfaceArgs(func_one, ThisType)) u8,
        func_with_args_fn: *const fn (InterfaceArgs(func_with_args, ThisType)) u8,
    };
    pub const InterfaceType = Interface(@This());

    pub fn static_func(self: *const @This()) u8 {
        return InterfaceType.funcs(self).*.static_func_fn();
    }

    pub fn func_one(self: *const @This()) u8 {
        return InterfaceType.funcs(self).*.func_one_fn(.{InterfaceType.inner(self)});
    }

    pub fn func_with_args(self: *const @This(), lhs: u8, rhs: u8) u8 {
        return InterfaceType.funcs(self).*.func_with_args_fn(.{ InterfaceType.inner(self), lhs, rhs });
    }
};

//====================================================================================

const TestStruct = struct {
    pub fn static_func() u8 {
        return 5;
    }

    pub fn func_one(self: *const @This()) u8 {
        return self.number;
    }
    pub fn func_with_args(self: *const @This(), lhs: u8, rhs: u8) u8 {
        return self.number + lhs + rhs;
    }
    number: u8 = 6,
};
```
### Usage
```Zig
var test_struct = TestStruct{};
const test_inter = ITestStruct.InterfaceType.make(&test_struct);

try std.testing.expectEqual(test_inter.face.static_func(), 5);
try std.testing.expectEqual(test_inter.face.func_one(), 6);
try std.testing.expectEqual(test_inter.face.func_with_args(1, 2), 9);
```

## Interface

* Define your interface type.
* Define a type inside the interface with the name `FunctionTable`.
* In the FunctionTable, give the function pointers the same name as the functions in the
interface with `_fn` appended. The function signature of the function pointer can be
specified using the `InterfaceArgs` helper, for functions that are expected to be methods.
```Zig
const FunctionTable = struct {
    static_func_fn: *const fn () u8,
    func_one_fn: *const fn (InterfaceArgs(func_one, ThisType)) u8,
    func_with_args_fn: *const fn (InterfaceArgs(func_with_args, ThisType)) u8,
};
```
* Define a type called `InterfaceType` and assign it `Interface(@This())`.
```Zig
pub const InterfaceType = Interface(@This());
```
* Define the functions for your interface, they should all use self as the first parameter.
* In the implementation of the function, you should access the underlying function table with `InterfaceType.funcs(self).*` and then call the function object with the forwarded args. The args should be passed in an arg tuple (an anonymous list should be enough to infer). The 'self' argument of methods for the implementing type can be retrieved with `InterfaceType.inner(self)`.
```Zig
pub fn static_func(self: *const @This()) u8 {
    return InterfaceType.funcs(self).*.static_func_fn();
}
pub fn func_one(self: *const @This()) u8 {
    return InterfaceType.funcs(self).*.func_one_fn(.{InterfaceType.inner(self)});
}
pub fn func_with_args(self: *const @This(), lhs: u8, rhs: u8) u8 {
    return InterfaceType.funcs(self).*.func_with_args_fn(.{ InterfaceType.inner(self), lhs, rhs });
}
```

All put together:
```Zig
const ITestStruct = struct {
    const ThisType = @This();
    const FunctionTable = struct {
        static_func_fn: *const fn () u8,
        func_one_fn: *const fn (InterfaceArgs(func_one, ThisType)) u8,
        func_with_args_fn: *const fn (InterfaceArgs(func_with_args, ThisType)) u8,
    };
    pub const InterfaceType = Interface(@This());

    pub fn static_func(self: *const @This()) u8 {
        return InterfaceType.funcs(self).*.static_func_fn();
    }
    pub fn func_one(self: *const @This()) u8 {
        return InterfaceType.funcs(self).*.func_one_fn(.{InterfaceType.inner(self)});
    }
    pub fn func_with_args(self: *const @This(), lhs: u8, rhs: u8) u8 {
        return InterfaceType.funcs(self).*.func_with_args_fn(.{ InterfaceType.inner(self), lhs, rhs });
    }
};
```

### Implementor
* Define your type that implements your interface. Function names and signatures should match
those defined in the interface, but the self param can be for the implementor type.
```Zig
const TestStruct = struct {
   pub fn static_func() u8 {
       return 5;
   }
   pub fn func_one(self: *const @This()) u8 {
       return self.number;
   }
   pub fn func_with_args(self: *const @This(), lhs: u8, rhs: u8) u8 {
       return self.number + lhs + rhs;
   }
   number: u8 = 6,
};
```
### Usage
* Instantiate your implementing type somewhere
```Zig
var test_struct = TestStruct{};
```
* Instantiate an interface to your type and start making function calls. Note that the interface
holds a pointer to your implementing type, so should not outlive the allocation.
```Zig
const test_inter = ITestStruct.InterfaceType.make(&test_struct);
try std.testing.expectEqual(test_inter.face.static_func(), 5);
try std.testing.expectEqual(test_inter.face.func_one(), 6);
try std.testing.expectEqual(test_inter.face.func_with_args(1, 2), 9);
```

## Static Interface
We also support interfaces for interfaces that only bind to standalone functions and no methods. Therefore they only need an implementation type, rather than a pointer to an instantiated implementation type.
### Sample
```Zig
 const ITestStruct = struct {
    const ThisType = @This();
    const FunctionTable = struct {
        static_func_fn: *const fn () u8,
        static_func_with_args_fn: *const fn (u8, u8) u8,
    };
    pub const InterfaceType = StaticInterface(@This());

    pub fn static_func(self: *const @This()) u8 {
        return InterfaceType.funcs(self).*.static_func_fn();
    }

    pub fn static_func_with_args(self: *const @This(), lhs: u8, rhs: u8) u8 {
        return InterfaceType.funcs(self).*.static_func_with_args_fn(lhs, rhs);
    }
};

//====================================================================================

const TestStruct = struct {
    pub fn static_func() u8 {
        return 5;
    }

    pub fn static_func_with_args(lhs: u8, rhs: u8) u8 {
        return lhs + rhs;
    }
};

const test_inter = ITestStruct.InterfaceType.make(TestStruct);

try std.testing.expectEqual(test_inter.face.static_func(), 5);
try std.testing.expectEqual(test_inter.face.static_func_with_args(1, 2), 3);
```
### Implements
There is the ability to query whether a type implements an interface.
```Zig
const TestInterface = struct {
    pub fn static_func(self: *const @This()) u8 {
        return self.static_func_fn();
    }

    pub fn func_one(self: *const @This()) u8 {
        return self.func_one_fn(.{self.inner});
    }

    pub fn func_with_args(self: *const @This(), lhs: u8, rhs: u8) u8 {
        return self.func_with_args_fn(.{ self.inner, lhs, rhs });
    }
};

//====================================================================================

const TestStructThatImplements = struct {
    pub fn static_func() u8 {
        return 5;
    }

    pub fn func_one(self: *const @This()) u8 {
        return self.number;
    }
    pub fn func_with_args(self: *const @This(), lhs: u8, rhs: u8) u8 {
        return self.number + lhs + rhs;
    }
    number: u8 = 6,
};

const TestStructNoImplement = struct {
    pub fn func_one(self: *const @This()) u8 {
        return self.number;
    }
    number: u8 = 7,
};

try std.testing.expect(implements(TestStructThatImplements, TestInterface).is_implemented);
try std.testing.expect(!implements(TestStructNoImplement, TestInterface).is_implemented);
```
