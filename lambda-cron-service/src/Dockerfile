FROM public.ecr.aws/lambda/nodejs:18

# Copy function code
COPY index.js package.json ${LAMBDA_TASK_ROOT}/

# Install dependencies
RUN npm install --production

# Set the CMD to your handler (could be overridden in function definition)
CMD ["index.handler"]