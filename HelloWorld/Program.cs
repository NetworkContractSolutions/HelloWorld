using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Azure.Identity;
using Microsoft.Extensions.Configuration.AzureAppConfiguration;

namespace HelloWorld
{
    public class Program
    {
        public static void Main(string[] args)
        {
            CreateHostBuilder(args).Build().Run();
        }

        public static IHostBuilder CreateHostBuilder(string[] args) =>
            Host.CreateDefaultBuilder(args)
                .ConfigureWebHostDefaults(webBuilder =>
                {
                    webBuilder.UseStartup<Startup>();
                })
                .ConfigureAppConfiguration((hostingContext, config) =>
                {
                    var configRoot = config.Build();
                    var endpoint = configRoot.GetSection("AppConfigurationSettings").GetValue<string>("Endpoint");
                    config.AddAzureAppConfiguration(options =>
                    {
                        var credential = new ManagedIdentityCredential();
                        options.Connect(new Uri(endpoint), credential)
                            // Load configuration values with no label
                            .Select(KeyFilter.Any, LabelFilter.Null)
                            // Override with any configuration values specific to current hosting env
                            .Select(KeyFilter.Any, hostingContext.HostingEnvironment.EnvironmentName);
                        // options.ConfigureRefresh(configure =>
                        // {
                        //     configure.Register("refreshSettings", true);
                        //     configure.SetCacheExpiration(TimeSpan.FromMinutes(10));
                        // });
                    });
                    config.Build();
                });
    }
}
