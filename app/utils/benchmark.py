from timeit import repeat


def benchmark(func):
    def wrapper(*args, **kwargs):
        bench_time = repeat(
            stmt="fn()", globals={"fn": func}, repeat=2, number=10
        )
        print(f"{func.__name__} took {bench_time}")

    return wrapper
