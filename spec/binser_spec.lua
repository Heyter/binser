local binser = require "binser"

local function test_ser(...)
    local serialized_data = binser.s(...)
    local results = { binser.d(serialized_data) }
    for i = 1, select("#", ...) do
        assert.are.same(select(i, ...), results[i])
    end
end

describe("binser", function()

    it("Serializes numbers", function()
        -- NaN should work, but lua thinks NaN ~= NaN
        test_ser(1, 2, 4, 809, -1290, math.huge, -math.huge, 0)
    end)

    it("Serializes numbers with no precision loss", function()
        test_ser(math.ldexp(0.985, 1023), math.ldexp(0.781231231, -1023),
            math.ldexp(0.5, -1021), math.ldexp(0.5, -1022))
    end)

    it("Serializes strings", function()
        test_ser("Hello, World!", "1231", "jojo", "binser", "\245897", "#####",
        "#|||||###|#|#|#!@|#|@|!||2121|2", "", "\000\x34\x67\x56", "\000\255" )
    end)

    it("Serializes booleans", function()
        test_ser(true, false, false, true)
    end)

    it("Serializes nil", function()
        test_ser(nil, nil, true, nil, nil, true, nil)
    end)

    it("Serializes simple tables", function()
        test_ser({0, 1, 2, 3}, {a = 1, b = 2, c = 3})
    end)

    it("Serializes tables", function()
        -- Using tables as keys throws a wrench into busted's "same" assert.
        -- i.e., busted's deep equals seems not to apply to table keys.
        -- This isn't a bug, just annoying.
        test_ser({0, 1, 2, 3, "a", true, nil, ["ranÎØM\000\255"] = "koi"}, {})
    end)

    it("Serializes cyclic tables", function()
        local tab = {
            a = 90,
            b = 89,
            zz = "binser",
        }
        tab["cycle"] = tab
        test_ser(tab, tab)
    end)

    it("Serializes metatables", function()
        local mt = {
            name = "MyCoolType"
        }
        test_ser(setmetatable({}, mt), setmetatable({
            a = "a",
            b = "b",
            c = "c"
        }, mt))
    end)

    it("Serializes custom tyes", function()
        local mt = {
            name = "MyCoolType"
        }
        binser.register(mt)
        test_ser(setmetatable({}, mt), setmetatable({
            a = "a",
            b = "b",
            c = "c"
        }, mt))
        binser.unregister(mt.name)
    end)

    it("Serializes custom type references", function()
        local mt = {
            name = "MyCoolType"
        }
        binser.register(mt)
        local a = setmetatable({}, mt)
        test_ser(a, a, a)
        local b1, b2, b3 = binser.d(binser.s(a, a, a))
        assert.are.same(b1, b2)
        assert.are.same(b2, b3)
        binser.unregister(mt.name)
    end)

    it("Serializes cyclic tables in constructors", function()
        local mt
        mt = {
            name = "MyCoolType",
            _serialize = function(x)
                local a = {value = x.value}
                a[a] = a -- add useless cycling to try and confuse the serializer
                return a
            end,
            _deserialize = function(a)
                return setmetatable({value = a.value}, mt)
            end
        }
        binser.register(mt)
        local a = setmetatable({value = 30}, mt)
        local b = setmetatable({value = 40}, mt)
        local c = {}
        c.a = a
        c.b = b
        test_ser(a, c, b)
        binser.unregister(mt.name)
    end)

    it("Serializes functions", function()
        local function myFn(a, b)
            return (a + b) * math.sqrt(a + b)
        end
        local myNewFn = binser.d(binser.s(myFn))
        assert.are.same(myNewFn(10, 9), myFn(10, 9))
    end)

    it("Serializes with resources", function()
        local myResource = {"This is a resource."}
        binser.registerResource(myResource, "myResource")
        test_ser({1, 3, 5, 7, 8, myResource})

        local data = binser.s(myResource)
        myResource[2] = "This is some new data."
        local deserdata = binser.d(data)
        assert(myResource == deserdata)

        binser.unregisterResource("myResource")
    end)

    it("Serializes serpent's benchmark data", function()
        -- test data
        local b = {text="ha'ns", ['co\nl or']='bl"ue', str="\"\n'\\\001"}
        local a = {
          x=1, y=2, z=3,
          ['function'] = b, -- keyword as a key
          list={'a',nil,nil, -- shared reference, embedded nils
                [9]='i','f',[5]='g',[7]={}}, -- empty table
          ['label 2'] = b, -- shared reference
          [math.huge] = -math.huge, -- huge as number value
        }
        a.c = a -- self-reference
        local c = {}
        for i = 1, 500 do
           c[i] = i
        end
        a.d = c
        -- test data
        test_ser(a)
    end)

    it("Fails gracefully on impossible constructors", function()
        local mt = {
            name = "MyCoolType",
            _serialize = function(x) return x end,
            _deserialize = function(x) return x end
        }
        binser.register(mt)
        local a = setmetatable({}, mt)
        assert.has_error(function() binser.s(a, a, a) end, "Infinite loop in constructor.")
        binser.unregister(mt.name)
    end)

    it("Can use templates to have more efficient custom serialization and deserialization", function()
        local mt = {
            name = "marshalledtype",
            _template = {
                "cat", "dog", 0, false
            }
        }
        local a = setmetatable({
            cat = "meow",
            dog = "woof",
            [0] = "something",
            [false] = 1
        }, mt)
        binser.register(mt)
        test_ser(a)
        binser.unregister(mt)
    end)

    it("Can use nested templates", function()
        local mt = {
            name = "mtype",
            _template = {
                "movie", joe = { "age", "width", "height" }, "yolo"
            }
        }
        local a = setmetatable({
            movie = "Die Hard",
            joe = {
                age = 25,
                width = "kinda wide",
                height = "not so tall"
            },
            yolo = "bolo"
        }, mt)
        binser.register(mt)
        test_ser(a)
        binser.unregister(mt)
    end)

end)
