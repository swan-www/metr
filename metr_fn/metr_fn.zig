const std = @import("std");

// Public

///	Usage:
///
/// Define the interface type.
/// Define a type inside the interface with the name `FunctionTable`.
/// In the FunctionTable, give the function pointers the same name as the functions in the
/// interface with `_fn` appended. The function signature of the function pointer should
/// match the interface function directly.
/// Define a type called `InterfaceType` and assign it `StaticInterface(@This())`.
/// Define the functions for your interface, they should all use self as the first parameter.
/// In the implementation of the function, you should access the underlying function table
/// with `InterfaceType.funcs(self).*` and then call the function object with the forwarded args.
///
/// const ITestStruct = struct {
///     const ThisType = @This();
///     const FunctionTable = struct {
///         static_func_fn: *const fn () u8,
///         static_func_with_args_fn: *const fn (u8, u8) u8,
///     };
///     pub const InterfaceType = StaticInterface(@This());
///
///     pub fn static_func(self: *const @This()) u8 {
///         return InterfaceType.funcs(self).*.static_func_fn();
///     }
///
///     pub fn static_func_with_args(self: *const @This(), lhs: u8, rhs: u8) u8 {
///         return InterfaceType.funcs(self).*.static_func_with_args_fn(lhs, rhs);
///     }
/// };
///
/// //====================================================================================
///
/// Define your type that implements your interface. Function names and signatures should match
/// those defined in the interface.
///
/// const TestStruct = struct {
///     pub fn static_func() u8 {
///         return 5;
///     }
///
///     pub fn static_func_with_args(lhs: u8, rhs: u8) u8 {
///         return lhs + rhs;
///     }
/// };
///
/// Instantiate an interface to your type and start making function calls.
///
/// const test_inter = ITestStruct.InterfaceType.make(TestStruct);
///
/// try std.testing.expectEqual(test_inter.face.static_func(), 5);
/// try std.testing.expectEqual(test_inter.face.static_func_with_args(1, 2), 3);
///
pub fn StaticInterface(comptime interface_type: type) type {
    return struct {
        face: interface_type,
        function_table_ptr: *const interface_type.FunctionTable,

        pub fn make(implementor_type: type) @This() {
            const Static = struct {
                const function_table = bind(implementor_type, interface_type);
            };

            return @This(){
                .face = interface_type{},
                .function_table_ptr = &Static.function_table,
            };
        }

        pub fn funcs(interf: *const interface_type) *const interface_type.FunctionTable {
            const ptrToThis: *const @This() = @alignCast(@fieldParentPtr("face", interf));
            return ptrToThis.*.function_table_ptr;
        }
    };
}

///	Usage:
///
/// Define the interface type.
/// Define a type inside the interface with the name `FunctionTable`.
/// In the FunctionTable, give the function pointers the same name as the functions in the
/// interface with `_fn` appended. The function signature of the function pointer can be
/// specified using the `InterfaceArgs` helper, for functions that are expected to be methods.
/// Define a type called `InterfaceType` and assign it `Interface(@This())`.
/// Define the functions for your interface, they should all use self as the first parameter.
/// In the implementation of the function, you should access the underlying function table
/// with `InterfaceType.funcs(self).*` and then call the function object with the forwarded args.
/// The args should be passed in an arg tuple (an anonymous list should be enough to infer).
/// The 'self' argument of methods for the implementing type can be retrieved
/// with `InterfaceType.inner(self)`.
///
/// const ITestStruct = struct {
///     const ThisType = @This();
///     const FunctionTable = struct {
///         static_func_fn: *const fn () u8,
///         func_one_fn: *const fn (InterfaceArgs(func_one, ThisType)) u8,
///         func_with_args_fn: *const fn (InterfaceArgs(func_with_args, ThisType)) u8,
///     };
///     pub const InterfaceType = Interface(@This());
///
///     pub fn static_func(self: *const @This()) u8 {
///         return InterfaceType.funcs(self).*.static_func_fn();
///     }
///
///     pub fn func_one(self: *const @This()) u8 {
///         return InterfaceType.funcs(self).*.func_one_fn(.{InterfaceType.inner(self)});
///     }
///
///     pub fn func_with_args(self: *const @This(), lhs: u8, rhs: u8) u8 {
///         return InterfaceType.funcs(self).*.func_with_args_fn(.{ InterfaceType.inner(self), lhs, rhs });
///     }
/// };
///
/// //====================================================================================
///
/// Define your type that implements your interface. Function names and signatures should match
/// those defined in the interface, but the self param can be for the implementor type.
///
/// const TestStruct = struct {
///      pub fn static_func() u8 {
///          return 5;
///      }
///
///      pub fn func_one(self: *const @This()) u8 {
///          return self.number;
///      }
///      pub fn func_with_args(self: *const @This(), lhs: u8, rhs: u8) u8 {
///          return self.number + lhs + rhs;
///      }
///      number: u8 = 6,
///  };
///
/// Instantiate your implementing type somewhere
///
/// var test_struct = TestStruct{};
///
/// Instantiate an interface to your type and start making function calls. Note that the interface
/// holds a pointer to your implementing type, so should not outlive the allocation.
///
/// const test_inter = ITestStruct.InterfaceType.make(&test_struct);
///
/// try std.testing.expectEqual(test_inter.face.static_func(), 5);
/// try std.testing.expectEqual(test_inter.face.func_one(), 6);
/// try std.testing.expectEqual(test_inter.face.func_with_args(1, 2), 9);
///
pub fn Interface(comptime interface_type: type) type {
    return struct {
        face: interface_type,
        function_table_ptr: *const interface_type.FunctionTable,
        impl: *anyopaque,

        pub fn make(implementor_ptr: anytype) @This() {
            const ImplementorPtrTypeID = @typeInfo(@TypeOf(implementor_ptr));
            if (ImplementorPtrTypeID != .Pointer) {
                @compileError("Expected pointer to implementation");
            }

            const implementor_type = ImplementorPtrTypeID.Pointer.child;

            const Static = struct {
                const function_table = bind(implementor_type, interface_type);
            };

            return @This(){
                .face = interface_type{},
                .function_table_ptr = &Static.function_table,
                .impl = implementor_ptr,
            };
        }

        pub fn inner(interf: *const interface_type) *anyopaque {
            const ptrToThis: *const @This() = @alignCast(@fieldParentPtr("face", interf));
            return ptrToThis.*.impl;
        }

        pub fn funcs(interf: *const interface_type) *const interface_type.FunctionTable {
            const ptrToThis: *const @This() = @alignCast(@fieldParentPtr("face", interf));
            return ptrToThis.*.function_table_ptr;
        }
    };
}

/// Information about mismatched function arg
pub const FnArgTypeMismatchResult = struct {
    fn_name: []const u8,
    expected_args: type,
    found_args: type,

    const fmt_str =
        \\{{
        \\  .fn_name = {{{s}}},
        \\  .expected_args = {{{s}}},
        \\  .found_args = {{{s}}},
        \\}}
    ;

    pub fn to_str(comptime self: FnArgTypeMismatchResult) *const [
        std.fmt.count(fmt_str, .{ self.fn_name, @typeName(self.expected_args), @typeName(self.found_args) })
        :
        0
    ]u8 {
        return std.fmt.comptimePrint(fmt_str, .{ self.fn_name, @typeName(self.expected_args), @typeName(self.found_args) });
    }
};

/// Return information about whether a type implements a function from an interface.
pub const ImplementsResult = struct {
    is_implemented: bool = true,
    missing_functions: []const []const u8 = &.{},
    mismatch_arg_functions: []const FnArgTypeMismatchResult = &.{},

    pub fn to_str(comptime self: ImplementsResult) []const u8 {
        var missing_funcs_joined: []const u8 = "";
        for (self.missing_functions) |missing_func| {
            missing_funcs_joined = missing_funcs_joined ++ std.fmt.comptimePrint("{s},\n", .{missing_func});
        }

        var mismatched_funcs_joined: []const u8 = "";
        for (self.mismatch_arg_functions) |mismatch_func| {
            mismatched_funcs_joined = mismatched_funcs_joined ++ std.fmt.comptimePrint("{s},\n", .{mismatch_func.to_str()});
        }

        return std.fmt.comptimePrint(
            \\{{
            \\  .is_implemented = {}
            \\  .missing_functions = {{{s}}}
            \\  .mismatched_functions = {{{s}}}
            \\}}
        , .{ self.is_implemented, missing_funcs_joined, mismatched_funcs_joined });
    }
};

// Query whether an implementing type implements all of the expected functions from an interface type.
pub fn implements(implementor_type: type, interface_type: type) ImplementsResult {
    //Get the function declarations in the interface type
    const interface_fn_names = get_function_names(interface_type);
    var result = ImplementsResult{};

    //for each interface function, get remapped args.
    for (interface_fn_names) |i_fn| {
        if (!@hasDecl(implementor_type, i_fn.name)) {
            result.is_implemented = false;
            result.missing_functions = result.missing_functions ++ [_][]const u8{i_fn.name};
            continue;
        }

        const fn_arg_tuple_type = remap_args_for_self(@field(implementor_type, i_fn.name), implementor_type, anyopaque);
        const expected_arg_tuple = remap_args_for_self(@field(interface_type, i_fn.name), interface_type, anyopaque);
        const expected_static_arg_tuple = remap_args_for_self(@field(interface_type, i_fn.name), interface_type, null);

        if (fn_arg_tuple_type != expected_arg_tuple and fn_arg_tuple_type != expected_static_arg_tuple) {
            result.is_implemented = false;
            result.mismatch_arg_functions = result.mismatch_arg_functions ++ .{.{
                .fn_name = i_fn.name,
                .expected_args = expected_arg_tuple,
                .found_args = fn_arg_tuple_type,
            }};
        }
    }

    return result;
}

//Helper type for auto-generating function pointer arg types for the function-table
pub fn InterfaceArgs(target_fn: anytype, InterfaceType: type) type {
    return remap_args_for_self(target_fn, InterfaceType, anyopaque);
}

// Private

const RemoveType = struct {};

//Passing the substitute type as null will remove the type instead of replacing it
fn remap_args_for_self(target_fn: anytype, type_to_replace: type, type_to_substitute: ?type) type {
    const underlying_fn_typeinfo = @typeInfo(@TypeOf(target_fn));
    switch (underlying_fn_typeinfo) {
        .Fn => {},
        else => |wrong_val| @compileError("Expected only functions to be passed into `interface_fn_wrapper`, found " ++ @tagName(wrong_val)),
    }

    const arg_tuple_type = std.meta.ArgsTuple(@TypeOf(target_fn));
    const arg_tuple_typeinfo = @typeInfo(arg_tuple_type);
    switch (arg_tuple_typeinfo) {
        .Struct => {},
        else => |wrong_val| @compileError("Expected arg tuple type to be a struct, found " ++ @tagName(wrong_val)),
    }

    var type_list: []const type = &.{};
    inline for (arg_tuple_typeinfo.Struct.fields, 0..) |field, i| {
        if (i == 0) {
            const remapped_type = switch (field.type) {
                *const type_to_replace => if (type_to_substitute != null) *const type_to_substitute.? else RemoveType,
                *type_to_replace => if (type_to_substitute != null) *type_to_substitute.? else RemoveType,
                else => field.type,
            };

            if (remapped_type != RemoveType) {
                type_list = type_list ++ [_]type{remapped_type};
            }
        } else {
            type_list = type_list ++ [_]type{field.type};
        }
    }

    return std.meta.Tuple(type_list);
}

fn wrapper_fn(ImplementationType: type, inner_fn_: anytype) fn (remap_args_for_self(inner_fn_, ImplementationType, anyopaque)) @typeInfo(@TypeOf(inner_fn_)).Fn.return_type.? {
    const WrapperStruct = struct {
        pub fn call(
            //inner_fn : @TypeOf(inner_fn_),
            outer_args: remap_args_for_self(inner_fn_, ImplementationType, anyopaque),
        ) @typeInfo(@TypeOf(inner_fn_)).Fn.return_type.? {
            const InnerArgsType = std.meta.ArgsTuple(@TypeOf(inner_fn_));
            var inner_args: InnerArgsType = undefined;
            inline for (0..outer_args.len) |i| {
                if (i == 0) {
                    const field_info = @typeInfo(@typeInfo(InnerArgsType).Struct.fields[0].type);
                    if (field_info == .Pointer) {
                        if (field_info.Pointer.is_const) {
                            inner_args[i] = @as(*const ImplementationType, @ptrCast(outer_args[i]));
                        } else {
                            inner_args[i] = @as(*ImplementationType, @ptrCast(outer_args[i]));
                        }
                    } else {
                        inner_args[i] = outer_args[i];
                    }
                } else {
                    inner_args[i] = outer_args[i];
                }
            }

            return @call(std.builtin.CallModifier.auto, inner_fn_, inner_args);
        }
    };

    return WrapperStruct.call;
}

const FnName = struct {
    name: []const u8,
};

fn get_function_names(T: type) []const FnName {
    var fn_names: []const FnName = &.{};
    switch (@typeInfo(T)) {
        inline .Struct, .Enum, .Union, .Opaque => |container_info| {
            for (container_info.decls) |decl| {
                switch (@typeInfo(@TypeOf(@field(T, decl.name)))) {
                    .Fn => {
                        fn_names = fn_names ++ .{.{ .name = decl.name }};
                    },
                    else => {},
                }
            }
        },
        inline else => |_, tag| @compileError("Invalid type '" ++ @tagName(tag) ++ "' does not have functions."),
    }
    return fn_names;
}

test "implements test" {
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
}

test "standalone interface concept unused" {
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

        inner: *const anyopaque,
        static_func_fn: *const fn () u8,
        func_one_fn: *const fn (InterfaceArgs(func_one, @This())) u8,
        func_with_args_fn: *const fn (InterfaceArgs(func_with_args, @This())) u8,

        pub fn make(implementor_type: type, implementor: *const implementor_type) @This() {
            return @This(){
                .inner = implementor,
                .static_func_fn = implementor_type.static_func,
                .func_one_fn = wrapper_fn(implementor_type, implementor_type.func_one),
                .func_with_args_fn = wrapper_fn(implementor_type, implementor_type.func_with_args),
            };
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

    const test_struct = TestStruct{};
    const test_implementation = TestInterface.make(TestStruct, &test_struct);

    try std.testing.expectEqual(test_implementation.static_func(), 5);
    try std.testing.expectEqual(test_implementation.func_one(), 6);
    try std.testing.expectEqual(test_implementation.func_with_args(1, 2), 9);
}

pub fn bind(comptime implementor_type: type, comptime interface_type: type) interface_type.FunctionTable {
    const validity_check = implements(implementor_type, interface_type);
    if (!validity_check.is_implemented) {
        @compileError(validity_check.to_str());
    }

    const FunctionTable: type = interface_type.FunctionTable;
    var interface_to_bind: FunctionTable = undefined;

    const interface_fn_names = get_function_names(interface_type);
    for (interface_fn_names) |i_fn| {
        const fn_object_name = i_fn.name ++ "_fn";
        if (!@hasField(FunctionTable, fn_object_name)) {
            @compileError(std.fmt.comptimePrint("Expected interface {s} to have function object with name {s} in its FunctionTable.", .{ @typeName(interface_type), fn_object_name }));
        }

        const fn_arg_tuple_type = remap_args_for_self(@field(implementor_type, i_fn.name), implementor_type, anyopaque);
        const expected_arg_tuple = remap_args_for_self(@field(interface_type, i_fn.name), interface_type, anyopaque);
        const expected_static_arg_tuple = remap_args_for_self(@field(interface_type, i_fn.name), interface_type, null);

        if (fn_arg_tuple_type == expected_arg_tuple) {
            @field(interface_to_bind, fn_object_name) = wrapper_fn(implementor_type, @field(implementor_type, i_fn.name));
        } else if (fn_arg_tuple_type == expected_static_arg_tuple) {
            @field(interface_to_bind, fn_object_name) = @field(implementor_type, i_fn.name);
        }
    }

    return interface_to_bind;
}

test "Regular Interface test" {
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

    var test_struct = TestStruct{};
    const test_inter = ITestStruct.InterfaceType.make(&test_struct);

    try std.testing.expectEqual(test_inter.face.static_func(), 5);
    try std.testing.expectEqual(test_inter.face.func_one(), 6);
    try std.testing.expectEqual(test_inter.face.func_with_args(1, 2), 9);
}

test "Static Interface test" {
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
}
