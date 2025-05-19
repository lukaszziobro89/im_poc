# Create the main package and subpackages
mkdir -p input_management/{api,common,errors,schemas}
touch input_management/__init__.py
touch input_management/app.py
touch input_management/classification.py

# Create API module files
touch input_management/api/__init__.py
touch input_management/api/classification.py
touch input_management/api/extensions.py

# Create common module files
touch input_management/common/__init__.py
touch input_management/common/health.py

# Create errors module files
touch input_management/errors/__init__.py
touch input_management/errors/exceptions.py
touch input_management/errors/handlers.py

# Create schemas module files
touch input_management/schemas/__init__.py
touch input_management/schemas/requests.py
touch input_management/schemas/responses.py

# Create example implementation and main file
touch example_use_case.py
touch main.py
