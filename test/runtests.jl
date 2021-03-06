using Test
using JavaCall

import Dates
using Base.GC: gc


JavaCall.init(["-Djava.class.path=$(@__DIR__)"])
# JavaCall.init(["-verbose:gc","-Djava.class.path=$(@__DIR__)"])
# JavaCall.init()

@testset "unsafe_strings_1" begin
    a=JString("how are you")
    @test a.ptr != C_NULL
    @test 11 == ccall(JavaCall.jnifunc.GetStringUTFLength, jint, (Ptr{JavaCall.JNIEnv}, Ptr{Nothing}),
                      JavaCall.penv, a.ptr)
    b = ccall(JavaCall.jnifunc.GetStringUTFChars, Ptr{UInt8},
              (Ptr{JavaCall.JNIEnv}, Ptr{Nothing}, Ptr{Nothing}), JavaCall.penv, a.ptr, C_NULL)
    @test unsafe_string(b) == "how are you"
end

T = @jimport Test

@testset "parameter_passing_1" begin
    @test 10 == jcall(T, "testShort", jshort, (jshort,), 10)
    @test 10 == jcall(T, "testInt", jint, (jint,), 10)
    @test 10 == jcall(T, "testLong", jlong, (jlong,), 10)
    @test typemax(jint) == jcall(T, "testInt", jint, (jint,), typemax(jint))
    @test typemax(jlong) == jcall(T, "testLong", jlong, (jlong,), typemax(jlong))
    @test "Hello Java"==jcall(T, "testString", JString, (JString,), "Hello Java")
    @test Float64(10.02) == jcall(T, "testDouble", jdouble, (jdouble,), 10.02) #Comparing exact float representations hence ==
    @test Float32(10.02) == jcall(T, "testFloat", jfloat, (jfloat,), 10.02)
    @test floatmax(jdouble) == jcall(T, "testDouble", jdouble, (jdouble,), floatmax(jdouble))
    @test floatmax(jfloat) == jcall(T, "testFloat", jfloat, (jfloat,), floatmax(jfloat))
    c=JString(C_NULL)
    @test isnull(c)
    @test "" == jcall(T, "testString", JString, (JString,), c)
end

@testset "static_method_call_1" begin
    jlm = @jimport "java.lang.Math"
    @test 1.0 ≈ jcall(jlm, "sin", jdouble, (jdouble,), pi/2)
    @test 1.0 ≈ jcall(jlm, "min", jdouble, (jdouble,jdouble), 1,2)
    @test 1 == jcall(jlm, "abs", jint, (jint,), -1)
end

@testset "instance_methods_1" begin
    jnu = @jimport java.net.URL
    gurl = jnu((JString,), "https://en.wikipedia.org")
    @test "en.wikipedia.org"==jcall(gurl, "getHost", JString,())
    jni = @jimport java.net.URI
    guri=jcall(gurl, "toURI", jni,())
    @test typeof(guri)==jni

    h=jcall(guri, "hashCode", jint,())
    @test typeof(h)==jint
end

#Test NULL
@testset "null_1" begin
    H=@jimport java.util.HashMap
    a=jcall(T, "testNull", H, ())
    @test_throws ErrorException jcall(a, "toString", JString, ())
end

@testset "arrays_1" begin
    j_u_arrays = @jimport java.util.Arrays
    @test 3 == jcall(j_u_arrays, "binarySearch", jint, (Array{jint,1}, jint), [10,20,30,40,50,60], 40)
    @test 2 == jcall(j_u_arrays, "binarySearch", jint, (Array{JObject,1}, JObject), ["123","abc","uvw","xyz"], "uvw")

    a=jcall(j_u_arrays, "copyOf", Array{jint, 1}, (Array{jint, 1}, jint), [1,2,3], 3)
    @test typeof(a) == Array{jint, 1}
    @test a[1] == Int32(1)
    @test a[2] == Int32(2)
    @test a[3] == Int32(3)

    a=jcall(j_u_arrays, "copyOf", Array{JObject, 1}, (Array{JObject, 1}, jint), ["a","b","c"], 3)
    @test 3==length(a)
    @test "a"==unsafe_string(convert(JString, a[1]))
    @test "b"==unsafe_string(convert(JString, a[2]))
    @test "c"==unsafe_string(convert(JString, a[3]))

    @test jcall(T, "testDoubleArray", Array{jdouble,1}, ()) == [0.1, 0.2, 0.3]
    @test jcall(T, "testDoubleArray2D", Array{Array{jdouble, 1},1}, ()) == [[0.1, 0.2, 0.3], [0.4, 0.5, 0.6]]
    @test jcall(T, "testDoubleArray2D", Array{jdouble,2}, ()) == [0.1 0.2 0.3; 0.4 0.5 0.6]
    @test size(jcall(T, "testStringArray2D", Array{JString,2}, ())) == (2,2)
end

@testset "dates_1" begin
    jd = @jimport(java.util.Date)(())
    jcal = @jimport(java.util.GregorianCalendar)(())
    jsd =  @jimport(java.sql.Date)((jlong,),round(jlong, time()))

    @test typeof(convert(Dates.DateTime, jd)) == Dates.DateTime
    @test typeof(convert(Dates.DateTime, jcal)) == Dates.DateTime
    @test typeof(convert(Dates.DateTime, jsd)) == Dates.DateTime
    nulldate = @jimport(java.util.Date)(C_NULL)
    @test Dates.year(convert(Dates.DateTime, nulldate)) == 1970
    nullcal = @jimport(java.util.GregorianCalendar)(C_NULL)
    @test Dates.year(convert(Dates.DateTime, nullcal)) == 1970

    @test Dates.year(convert(Dates.DateTime, nullcal)) == 1970
end

@testset "map_conversion_1" begin
    JHashMap = @jimport(java.util.HashMap)
    p = JHashMap(())
    a= Dict("a"=>"A", "b"=>"B")
    b=convert(@jimport(java.util.Map), JString, JString, a)
    @test jcall(b, "size", jint, ()) == 2
end

@testset "array_list_conversion_1" begin
    JArrayList = @jimport(java.util.ArrayList)
    p = JArrayList(())
    a = ["hello", " ", "world"]
    b = convert(@jimport(java.util.ArrayList), a, JString)
    @test jcall(b, "size", jint, ()) == 3
end

@testset "inner_classes_1" begin
    TestInner = @jimport(Test$TestInner)
    JTest = @jimport(Test)
    t=JTest(())
    inner = TestInner((JTest,), t)
    @test jcall(inner, "innerString", JString, ()) == "from inner"
    @test jfield(@jimport(java.lang.Math), "E", jdouble) == 2.718281828459045
    @test jfield(@jimport(java.lang.Math), "PI", jdouble) == 3.141592653589793
    @test jfield(@jimport(java.text.NumberFormat), "INTEGER_FIELD", jint) == 0
    Locale = @jimport java.util.Locale
    lc = jfield(@jimport(java.util.Locale), "CANADA", @jimport(java.util.Locale))
    #Instance field access
    #Disabled for now. Need to verify stability
    @test jfield(@jimport(java.util.logging.Logger), "GLOBAL_LOGGER_NAME", JString ) == "global"
    @test jcall(lc, "getCountry", JString, ()) == "CA"
    @test jfield(t, "integerField", jint) == 100
    @test jfield(t, "stringField", JString) == "A STRING"
end

# Test Memory allocation and de-allocatios
# the following loop fails with an OutOfMemoryException in the absence of de-allocation
# However, since Java and Julia memory are not linked, and manual gc() is required.
gc()
for i in 1:100000
	a=JString("A"^10000); #deleteref(a);
	if (i%10000 == 0); gc(); end
end

@testset "sinx_1" begin
    @test_throws UndefVarError jcall(jlm, "sinx", jdouble, (jdouble,), 1.0)
    @test_throws UndefVarError jcall(jlm, "sinx", jdouble, (jdouble,), 1.0)
end

@testset "method_lists_1" begin
    @test length(listmethods(JString("test"))) >= 72
    @test length(listmethods(JString("test"), "indexOf")) >= 3
    # the same for the type
    @test length(listmethods(JString)) >= 72
    @test length(listmethods(JString, "indexOf")) >= 3
    # the same for class
    @test length(listmethods(getclass(JString("test")))) >= 72
    @test length(listmethods(getclass(JString("test")), "indexOf")) >= 3
    m = listmethods(JString("test"), "indexOf")[1]
    @test getname(getreturntype(m)) == "int"

    v=jcall(@jimport("java.lang.System"), "getProperty", JString, (JString,), "java.version")
    v=replace(v, "_"=>"-")
    java_ver = macroexpand(Main, :(@v_str($v)))

    #Order of methods is different in JDK 9
    if java_ver < v"9.0.0-"
        @test [getname(typ) for typ in getparametertypes(m)] == ["java.lang.String", "int"]
    else
        @test [getname(typ) for typ in getparametertypes(m)] == ["int"]
    end
end

#Test for double free bug, #20
#Fix in #28. The following lines will segfault without the fix
@testset "double_free_1" begin
    JHashtable = @jimport java.util.Hashtable
    JProperties = @jimport java.util.Properties
    ta_20=Any[]
    for i=1:100; push!(ta_20, convert(JHashtable, JProperties((),))); end
    gc(); gc()
    for i=1:100; @test jcall(ta_20[i], "size", jint, ()) == 0; end
end

@testset "array_conversions_1" begin
    jobj = jcall(T, "testArrayAsObject", JObject, ())
    arr = convert(Array{Array{UInt8, 1}, 1}, jobj)
    @test ["Hello", "World"] == map(String, arr)
end

@testset "iterator_conversions_1" begin
    JArrayList = @jimport(java.util.ArrayList)
    a=JArrayList(())
    jcall(a, "add", jboolean, (JObject,), "abc")
    jcall(a, "add", jboolean, (JObject,), "cde")
    jcall(a, "add", jboolean, (JObject,), "efg")

    t=Array{Any, 1}()
    for i in JavaCall.iterator(a)
        push!(t, unsafe_string(i))
    end

    @test length(t) == 3
    @test t[1] == "abc"
    @test t[2] == "cde"
    @test t[3] == "efg"

    #Different iterator type - ListIterator
    t=Array{Any, 1}()
    for i in jcall(a, "listIterator", @jimport(java.util.ListIterator), ())
        push!(t, unsafe_string(i))
    end

    @test length(t) == 3
    @test t[1] == "abc"
    @test t[2] == "cde"
    @test t[3] == "efg"

    a=JArrayList(())
    t=Array{Any, 1}()
    for i in JavaCall.iterator(a)
        push!(t, unsafe_string(i))
    end
    @test length(t) == 0

    JStringClass = classforname("java.lang.String")
    @test isa(JStringClass, JavaObject{Symbol("java.lang.Class")})

    o = convert(JObject, "bla bla bla")
    @test isa(narrow(o), JString)
end


# At the end, unload the JVM before exiting
JavaCall.destroy()
