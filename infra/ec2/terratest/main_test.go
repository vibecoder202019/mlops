package test

import (
	"regexp"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/aws" // Add this import
    "github.com/gruntwork-io/terratest/modules/random" // Add this import
	"github.com/stretchr/testify/assert"
)

func TestInfrastructureOutputs(t *testing.T) {
	// 1. Define expected test variables
	expectedRegion := "us-east-1"
	expectedS3Bucket := "mlops-terratest-bucket"

    // 1. Generate a unique name for the key pair to avoid collisions
    uniqueId := random.UniqueId()
    expectedKeyName := "terratest-key-" + uniqueId
    // 2. Create an EC2 KeyPair specifically for this test
    keyPair := aws.CreateAndImportEC2KeyPair(t, expectedRegion, expectedKeyName)

    // 3. Ensure the KeyPair is deleted at the end of the test
    defer aws.DeleteEC2KeyPair(t, keyPair)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../terraform", // Adjust to the folder containing your .tf files

		Vars: map[string]interface{}{
			"aws_region":      expectedRegion,
			"key_name":        expectedKeyName,
			"s3_bucket":       expectedS3Bucket,
			"enable_gpu_node": false, // Set to false to test the conditional logic safely
			// Add any other required variables here
		},
	})

	// 2. Clean up resources when the test finishes
	defer terraform.Destroy(t, terraformOptions)

	// 3. Deploy the infrastructure
	terraform.InitAndApply(t, terraformOptions)

	// 4. Test Static Variables
	actualRegion := terraform.Output(t, terraformOptions, "aws_region_output")
	assert.Equal(t, expectedRegion, actualRegion)

	actualS3Bucket := terraform.Output(t, terraformOptions, "s3_bucket")
	assert.Equal(t, expectedS3Bucket, actualS3Bucket)

	// 5. Test IP Addresses using Regex
	// An IPv4 regex pattern to ensure AWS provisioned an IP
	ipRegex := regexp.MustCompile(`^(\d{1,3}\.){3}\d{1,3}$`)

	controlPublicIp := terraform.Output(t, terraformOptions, "control_public_ip")
	assert.Regexp(t, ipRegex, controlPublicIp)

	controlPrivateIp := terraform.Output(t, terraformOptions, "control_private_ip")
	assert.Regexp(t, ipRegex, controlPrivateIp)

	// 6. Test string interpolation outputs
	sshControl := terraform.Output(t, terraformOptions, "ssh_control")
	assert.True(t, strings.Contains(sshControl, expectedKeyName+".pem"))
	assert.True(t, strings.Contains(sshControl, controlPublicIp))

	lab1Url := terraform.Output(t, terraformOptions, "lab1_url_docker")
	assert.Equal(t, "http://"+controlPublicIp+":8000/docs", lab1Url)

	// 7. Test conditional logic (enable_gpu_node = false)
	sshGpu := terraform.Output(t, terraformOptions, "ssh_gpu")
	assert.Equal(t, "GPU node disabled", sshGpu)
}