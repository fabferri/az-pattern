// https://docs.microsoft.com/en-us/dotnet/api/overview/azure/security.keyvault.secrets-readme
using System;
using System.IO;
using Microsoft.Extensions.Configuration;
using System.Threading.Tasks;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using Azure;
using System.Collections.Generic;

namespace keyvault_console_app
{
    class Program
    {
        static async Task Main(string[] args)
        {
            //// keyvault name
            string keyVaultName = "";

            //// Client ID from the output of service pricipal creation output
            string clientId = "";

            //// Tenant ID from the output of service pricipal creation output
            string tenantId = "";

            //// Password from the output of service pricipal creation output
            string clientSecret = "";
            
            Dictionary<string, string> listValues = new Dictionary<string, string>();
            Console.WriteLine($"reading variable from the file jsconfig1.json");
            listValues = GetParameters();
            foreach (KeyValuePair<string, string> kvp in listValues)
            {
                switch (kvp.Key)
                {
                    case "keyvaultName":
                        keyVaultName = kvp.Value;
                        Console.WriteLine($"keyvaultName= \"{kvp.Value}\"");
                        break;
                    case "clientId":
                        clientId = kvp.Value;
                        Console.WriteLine($"clientId= \"{kvp.Value}\"");
                        break;
                    case "tenantId":
                        tenantId = kvp.Value;
                        Console.WriteLine($"tenantId= \"{kvp.Value}\"");
                        break;
                    case "clientSecret":
                        clientSecret = kvp.Value;
                        Console.WriteLine($"clientSecret= \"{kvp.Value}\"");
                        break;
                    default:
                        Console.WriteLine("ERROR in reading .json file");
                        System.Environment.Exit(0);
                        break;
                }
            }


           // 
 

            var kvUri = $"https://{keyVaultName}.vault.azure.net";
           
            // var client = new SecretClient(new Uri(kvUri), new DefaultAzureCredential());
            var client = new SecretClient(vaultUri: new Uri(kvUri), credential: new ClientSecretCredential(tenantId, clientId, clientSecret));

            // list all the deleted and non-purged secrets, assuming Azure Key Vault is soft delete-enabled.
            IEnumerable<DeletedSecret> secretsDeleted = client.GetDeletedSecrets();
            foreach (DeletedSecret secretDel in secretsDeleted)
            {
                Console.WriteLine($"deleted secret: {secretDel.Name} , recovery Id: {secretDel.RecoveryId}");
            }
            
            // purge deleted secrets
            foreach (DeletedSecret secretDel in secretsDeleted)
            {
                Console.ForegroundColor = ConsoleColor.Cyan;
                Console.WriteLine("deleting secret: {0}", secretDel.Name);
                await client.PurgeDeletedSecretAsync(secretDel.Name);
                
                Console.WriteLine(" done.");
            }
            
            Console.WriteLine("-----------------------------------------");
            Console.ResetColor();

            // Create a new dictionary of strings, with string keys.
            //
            Dictionary<string, string> secretValues = new Dictionary<string, string>();
            secretValues.Add("secret01", "AAAA-BBBB-CCCC-DDDD-101");
            secretValues.Add("secret02", "EEEE-FFFF-GGGG-HHHH-101");
            secretValues.Add("secret03", "LLLL-MMMM-NNNN-OOOO-101");
            secretValues.Add("secret04", "PPPP-QQQQ-RRRR-SSSS-101");
            secretValues.Add("secret05", "TTTT-VVVV-WWWW-XXXX-101");
            secretValues.Add("secret06", "XXXX-YYYY-ZZZZ-AAAA-101");
            secretValues.Add("secret07", "BBBB-CCCC-DDDD-EEEE-101");
            secretValues.Add("secret08", "FFFF-GGGG-HHHH-IIII-101");
            secretValues.Add("secret09", "JJJJ-KKKK-LLLL-MMMM-101");
            secretValues.Add("secret10", "NNNN-OOOO-PPPP-QQQQ-101");
            secretValues.Add("secret11", "AAAA-BBBB-CCCC-DDDD-102");
            secretValues.Add("secret12", "EEEE-FFFF-GGGG-HHHH-102");
            secretValues.Add("secret13", "LLLL-MMMM-NNNN-OOOO-102");
            secretValues.Add("secret14", "PPPP-QQQQ-RRRR-SSSS-102");
            secretValues.Add("secret15", "TTTT-VVVV-WWWW-XXXX-102");
            secretValues.Add("secret16", "XXXX-YYYY-ZZZZ-AAAA-102");
            secretValues.Add("secret17", "BBBB-CCCC-DDDD-EEEE-102");
            secretValues.Add("secret18", "FFFF-GGGG-HHHH-IIII-102");
            secretValues.Add("secret19", "JJJJ-KKKK-LLLL-MMMM-102");
            secretValues.Add("secret20", "NNNN-OOOO-PPPP-QQQQ-102");
            secretValues.Add("secret21", "AAAA-BBBB-CCCC-DDDD-103");
            secretValues.Add("secret22", "EEEE-FFFF-GGGG-HHHH-103");
            secretValues.Add("secret23", "LLLL-MMMM-NNNN-OOOO-103");
            secretValues.Add("secret24", "PPPP-QQQQ-RRRR-SSSS-103");
            secretValues.Add("secret25", "TTTT-VVVV-WWWW-XXXX-103");
            secretValues.Add("secret26", "XXXX-YYYY-ZZZZ-AAAA-103");
            secretValues.Add("secret27", "BBBB-CCCC-DDDD-EEEE-103");
            secretValues.Add("secret28", "FFFF-GGGG-HHHH-IIII-103");
            secretValues.Add("secret29", "JJJJ-KKKK-LLLL-MMMM-103");
            secretValues.Add("secret30", "NNNN-OOOO-PPPP-QQQQ-103");


            Dictionary<string, string> secretDictionary = new Dictionary<string, string>();
            AsyncPageable<SecretProperties> allSecrets1 = client.GetPropertiesOfSecretsAsync();
            await foreach (SecretProperties secretProperties in allSecrets1)
            {
                var fetchSecret = await client.GetSecretAsync(secretProperties.Name);
                secretDictionary.Add(fetchSecret.Value.Name, fetchSecret.Value.Value);
            }
            
            foreach (KeyValuePair<string, string> kvp in secretValues)
            {

                string value = "";
                if (secretDictionary.TryGetValue(kvp.Key, out value))
                
                {
                    Console.WriteLine("secret in keyvault: Key = {0}, Value = {1}", kvp.Key, kvp.Value);
                }
                else
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine("---> adding secret: Key = {0}, Value = {1}", kvp.Key, kvp.Value);
                    await client.SetSecretAsync(kvp.Key, kvp.Value);
                    Console.ResetColor();
                }
            }
            Console.ResetColor();
            Console.WriteLine("press a key to continue");
            Console.ReadKey();

            string[] listSecretNameToUpdate = { "secret15", "secret16", "secret17", "secret18", "secret19" };
            foreach (string secretName_ in listSecretNameToUpdate)
            {
                // update secrets
                await foreach (SecretProperties secret in client.GetPropertiesOfSecretVersionsAsync(secretName_))
                {
                    // Secret versions may also be disabled if compromised and new versions generated, so skip disabled versions, too.
                    if (!secret.Enabled.GetValueOrDefault())
                    {
                        continue;
                    }
                    System.DateTime moment = DateTime.Now;
                    int minute = moment.Minute;
                    int second = moment.Second;
                    string sVal = secretName_ +"-"+ minute.ToString("00") + second.ToString("00")+"-AAAAAAA";

                    KeyVaultSecret oldSecret = await client.GetSecretAsync(secret.Name, secret.Version);
                    if (sVal != oldSecret.Value)
                    {
                        Console.ForegroundColor = ConsoleColor.Green;
                        Console.WriteLine($"update the secret: {sVal} ...");
                        await client.SetSecretAsync(secret.Name,  sVal);
                        Console.ResetColor();
                    }
                }
            }

            // list of secrets to delete
            string[] listSecretName = { "secret15", "secret16", "secret17", "secret18", "secret19" };
            foreach (string secretName_ in listSecretName)
            {
                Console.Write($"Deleting your secret {secretName_} ...");
                DeleteSecretOperation operation = await client.StartDeleteSecretAsync(secretName_);
                // You only need to wait for completion if you want to purge or recover the secret.
                await operation.WaitForCompletionAsync();
                Console.WriteLine(" done.");
            }


            // list all the deleted and non-purged secrets, assuming Azure Key Vault is soft delete-enabled.
            IEnumerable<DeletedSecret> secretsDeleted_ = client.GetDeletedSecrets();
            // purge deleted secrets
            foreach (DeletedSecret secretDel in secretsDeleted_)
            {
                Console.ForegroundColor = ConsoleColor.Cyan;
                Console.WriteLine("purge deleted secret: {0}", secretDel.Name);
                await client.PurgeDeletedSecretAsync(secretDel.Name);
                Console.WriteLine(" done.");
                Console.ResetColor();
            }

        }

        // read the file "jsconfig1.json" and load the key, value pairs in the dictionary
        private static Dictionary<string,string> GetParameters()
        {
            var builder = new ConfigurationBuilder()
               .SetBasePath(Directory.GetCurrentDirectory())
               .AddJsonFile("jsconfig1.json", optional: true, reloadOnChange: true);
            var val1 = builder.Build().GetSection("keyvaultName").Value;
            var val2 = builder.Build().GetSection("clientId").Value;
            var val3 = builder.Build().GetSection("tenantId").Value;
            var val4 = builder.Build().GetSection("clientSecret").Value;
            Dictionary<string, string> listValues = new Dictionary<string, string>();
            listValues.Add("keyvaultName", val1);
            listValues.Add("clientId", val2);
            listValues.Add("tenantId", val3);
            listValues.Add("clientSecret", val4);
            return listValues;
        }
    }
}
