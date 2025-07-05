
# Summary

Setup your own sf CI/CD pipeline using github actions and the steps/code is right here. Reference section contains the references and the script directory contains the treasure you have been looking for. 

**Note FOR DUMMIES**: Its not an actual treasure, its the source code.

# Setting Up your own CI/CD

## Prerequisites:

Before we begin, its assumed that you have knowledge on salesforce, git & github. Its pretty obvious right? without that, cao my good friend! Apart from that, have the below will help you make precise modifications to the pipeline

- Basic knowledge on integartions.
- Basic knowledge on github actions.
- Hands on Experience in cli applications.
- Good Knowledge on utilizing CI/CD pipeline.

## About CI/CD for Salesforce

Like me, you felt very excited when you first stumbled upon the idea of CI/CD automating your sf deployments, you have discovered this repo and you copy pasted the code into your github repo and that its you are all set 😎, **FOR FAILURE !!!**

So why did it fail? Did you check copy pasting it again? Did you do something wrong with the copy paste? Try downloading the file. It still fails. Now that you are quite sure that there is more to it, lets get deep dived into the architecture of it.

## Architecture

### Integration

Github is a 3rd party service foregin to Salesforce. We must make sure that we provide sufficient information and access to allow github to authenticate to salesforce and perform the necessary deployment **AKA** Integration.

There are several processes to integration, but my personal choice is jwt authentication rather than the sfdx credential authentication. Its soloely because the sfdx requests and the your actual deployment requests are clubed together in later. Having a different setup only for development through github is always good, introduces a separation between your different automations.

The data necessary for integration is stored in the [github secrets](https://docs.github.com/en/actions/how-tos/security-for-github-actions/security-guides/security-hardening-for-github-actions), which is a secure way of storing sensitive data within github. (like named credentials in salesforce.)

Also, all the solutions I have explored online use a single user to deploy the metadata to next org. So, for a team of more than one, any deployment done by any memeber of the team is performed based on the user whose username is stored in the github secret - SF_USERNAME. Thus in the higher env, the last modified will always be shown as the user with user name in SF-USERNAME. To avoid this, we have implemented a workaround, create a field VCS_username__c on user object and put the github username of the developer in his user record. This way, our pipeline would identifies & authenticates with the intended user and deploys on his behalf. This maintains the correct trace in salesforce's last modified by field of any metadata.

> **NOTE:** This makes 3 integration requests to Salesforce and requires creation of the field vcs_username__c in user object & populating its relavent data.
>  **Integration Request 1**: Authenticate to Salesforce with the sf username in secret.  
>  **Integration Request 2**: Pick the github username from the PR author and get his sf username from query.  
>  **Integration Request 3**: Authenticate to Salesforce with sf username from the query's result.

Optionally you can skip the trouble of performing requests 2 & 3 by removing the step **Fetch User** from the scripts.

You can also create a pattern where your github username & sf username have certain pattern and use that pattern to dynamically generate your sf username based out of github username which will avoid step 2 & 3.


### Identifying delta

Once github integrates to Salesforce, our next job is to find out what metadata to deploy. Considering the requriment is for enterprise level salesforce org and not your personal projects, your deployment is based out of a requirement or a release. So its a sub set of metadata that needs to be deployed. If your requirement is build in a feature branch, then congratulations!! we have sf plugin for that!!!

Meet [scolladon](https://github.com/scolladon), the author of the sf plugin [sfdx-git-delta](https://github.com/scolladon/sfdx-git-delta) which automatically generates a mdapi package file from differences between 2 commits. In case of a requirement, the head of the feature branch and the branch from which the feature branch was created. The differences would be the metadata modified for the requriement and likely this modified metadata must be delpoyed. The sf plugin creates a package file with the list of modified metadata.

### Validation

As the metadata to be deployed is generated automatically, to establish a certain level of control, we first validate the generated package file by performing a dry-run. This gives us 3 advantages.

- The package file's content is displayed **Get Modified Metadata** step, so your developer can confirm the changes.
- The dry-run validates your deployment before you proceed with the deployment
- Validate your developer's changes visually, kinda tech review.


### Merge Conflicts

This is an interesting scenario and quite a roadblock for my pipeline build. When a PR is raised and there are merge conflicts, the validation is paused until the merge conflict is resolved. Once the conflict is resolved, within our repo, the target branch is merged into our feature branch and sfdx-git-delta plugin would pull up all the changes which are not just commited in our branch but also the changes which were merged into our target branch. If these changes are within our feature branch its well and good. But what if they are not? If your feature is created from a main branch and if the main is not your target branch, example, in case of INT or UAT deployment. We are screwed!!!

Worry not my fellow explorers, we handled it for you. Setup your deployment process in such a way that if a merge conflict is identified, then your developers are required to create a new branch from your feature branch as a place holder for your deployment. In our case, its \<feature branch>\_MC_\<Target Branch Code>. Update the script accordingly and you are good to. But wait, what exactly is happening behind the hood? its explained below

> - Assume you are deploying your feature branch **feature\-123** to your **UAT** environment. A PR is raised to merge the changes to **UAT** branch and you face a merge conflict.  
> - Your developer then creates a merge conflict branch **feature\-123_MC_UAT** from the feature branch **feature\-123** which acts like a place holder for the conflict resolution.
> - Once the conflict is resolved, the github action for validation is invoked. The script identified the occurance of merge conflict based on the branch naming convention & generates the package file from the original feature branch i.e, **feature\-123** but deploys metadata of the merge conflict branch i.e, **feature\-123_MC_UAT**.

Pretty neat right? The idea comes from the concept of promotion branch in copado but the branch is created only in case of merge conflict & conflict resolution takes place in a branch which is the copy of a feature branch and not the target branch. If there is a better way to do this, I am open to suggestions, post an issue and we can collaborate on this together.

### Test Classes

Test classes are just a pain in the saas, yet necessary. For this exact reason, any deployment involving an apex class or trigger, we run validation with tests. If the test classes are modified, they are auto picked up and run during the validation. If not, the developer mention the name of the test class in the PR template with in the phrases '**TestStart[**' and '**]TestStop**'. Multiple test classes must be separated by spaces.

> Add a test class named 'DemoClassTest':  
> 
> `TestStart[DemoClassTest]TestStop`
>
> Add test classes named 'DemoClassTest', 'TrailClassTest', 'IAmNotATest'
>
> `TestStart[DemoClassTest TrailClassTest IAmNotATest]TestStop`

This happens because of a (custom PR template)[./script/pull_request_template.md] and the format is configured within it. 

**NOTE**: The important thing here is to make sure that developers never use the phrases 'TestStart[' and ']TestStop' no where else in the PR body.

### Deployment
The deployment is triggered when the PR's changes are merged into the target branch. There is nothing much here, its the same stuff we do in the validation but with few steps skipped, like the test class run. We don't need to re run the tests as they are already run during our validation.

## Steps to Perform

### Integration

To setup the integration between github and salesforce perform the below steps.

#### Generate a Certificate for your Connected App
- Install the openssl application from [here](https://slproweb.com/products/Win32OpenSSL.html)
- Run the below commands:  

> Commands to create CSR & Key  
> 
> `openssl genrsa -des3 -passout pass:dummyPassword -out server.pass.key 2048`  
> 
> `openssl rsa -passin pass:dummyPassword -in server.pass.key -out server.key rm server.pass.key`
>
> `openssl req -new -key server.key -out server.csr`