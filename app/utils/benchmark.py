from timeit import repeat


def benchmark(func):
    def wrapper(*args, **kwargs):
        # Execute the function multiple times and benchmark the execution time
        bench_time = repeat(
            stmt="fn(*args, **kwargs)",
            globals={"fn": func, "args": args, "kwargs": kwargs},
            repeat=1,
            number=10,
        )

        # Calculate the best execution time (or you could use the average)
        avg_time = sum(bench_time) / len(bench_time)
        print(f"{func.__name__} took {avg_time:.6f} seconds (average of 2 repeats)")
        return func(*args, **kwargs)  # Ensure the function is still executed

    return wrapper
